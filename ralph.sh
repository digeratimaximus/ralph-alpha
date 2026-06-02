#!/usr/bin/env bash
# ralph.sh — a self-hosting Ralph loop. See README.md.
#
# Usage:
#   ./ralph.sh                 run the loop using ./ralph.env
#   ./ralph.sh --env path.env  run with a specific env file
#   ./ralph.sh --dry-run       print what each iteration WOULD do; never calls claude, never writes
#   ./ralph.sh --self-test     lint + sanity checks only; exit 0 if healthy (used as TEST_CMD for self-hosting)
#
# Safety: never merges; never pushes MAIN_BRANCH (spec markdown excepted); per-iteration git tag rollback;
# PAUSE file kill switch; MAX_ITERS / MAX_CONSEC_FAILURES / TIME_BUDGET_SECONDS circuit breakers.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/ralph.env"
DRY_RUN=0
SELF_TEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --self-test) SELF_TEST=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# --self-test: cheap health checks, no side effects. This is the back-pressure
# command for the self-hosting case (TEST_CMD in ralph.env.example).
# ---------------------------------------------------------------------------
if [ "$SELF_TEST" -eq 1 ]; then
  ok=1
  bash -n "$HERE/ralph.sh"            || { echo "FAIL: ralph.sh has a syntax error"; ok=0; }
  [ -f "$HERE/agent-loop/PROMPT.md" ] || { echo "FAIL: agent-loop/PROMPT.md missing"; ok=0; }
  [ -f "$HERE/agent-loop/METHOD.md" ] || { echo "FAIL: agent-loop/METHOD.md missing"; ok=0; }
  [ -f "$HERE/specs/README.md" ]      || { echo "FAIL: specs/README.md missing"; ok=0; }
  [ -f "$HERE/specs/approved.txt" ]   || { echo "FAIL: specs/approved.txt missing"; ok=0; }
  command -v shellcheck >/dev/null 2>&1 && { shellcheck -S warning "$HERE/ralph.sh" || { echo "FAIL: shellcheck"; ok=0; }; }

  # cost-tracking assertions
  grep -q 'COST_CEILING_USD' "$HERE/ralph.env.example" \
    && echo "PASS: COST_CEILING_USD documented in ralph.env.example" \
    || { echo "FAIL: COST_CEILING_USD missing from ralph.env.example"; ok=0; }
  _st_json="$HERE/agent-loop/state.json"
  if [ -f "$_st_json" ]; then
    if command -v jq >/dev/null 2>&1; then
      jq -e '.runs' "$_st_json" >/dev/null 2>&1 \
        && echo "PASS: state.json is valid JSON with runs key" \
        || { echo "FAIL: state.json invalid or missing runs key"; ok=0; }
    elif python3 -c "import json,sys; d=json.load(open('$_st_json')); assert 'runs' in d" 2>/dev/null; then
      echo "PASS: state.json is valid JSON with runs key"
    else
      echo "FAIL: state.json invalid or missing runs key"; ok=0
    fi
  else
    echo "FAIL: state.json not found at $_st_json"; ok=0
  fi

  # Assert ralph.env.example is source-able
  # shellcheck disable=SC1090
  if ( set +u; source "$HERE/ralph.env.example" ) 2>/dev/null; then
    echo "PASS: ralph.env.example source-able"
  else
    echo "FAIL: ralph.env.example not source-able"; ok=0
  fi

  # Assert --dry-run exits 0 and writes no files to reports/
  _dr_tmp="$(mktemp -d)"
  mkdir -p "$_dr_tmp/agent-loop"
  printf '# test\n' > "$_dr_tmp/agent-loop/PROMPT.md"
  printf 'REPO="%s"\nMODE="spec"\nTEST_CMD="true"\n' "$_dr_tmp" > "$_dr_tmp/ralph-dr.env"
  _dr_before="$(ls "$HERE/reports/" 2>/dev/null | wc -l | tr -d ' ')"
  "$HERE/ralph.sh" --dry-run --env "$_dr_tmp/ralph-dr.env" >/dev/null 2>&1; _dr_rc=$?
  _dr_after="$(ls "$HERE/reports/" 2>/dev/null | wc -l | tr -d ' ')"
  rm -rf "$_dr_tmp"
  if [ "$_dr_rc" -eq 0 ] && [ "$_dr_before" -eq "$_dr_after" ]; then
    echo "PASS: --dry-run smoke (exit 0, no reports/ files created)"
  else
    [ "$_dr_rc" -ne 0 ] && { echo "FAIL: --dry-run exited non-zero ($_dr_rc)"; ok=0; }
    [ "$_dr_before" -ne "$_dr_after" ] && { echo "FAIL: --dry-run created files in reports/"; ok=0; }
  fi

  # Assert MAX_CONSEC_FAILURES early-stop causes non-zero exit (uses a stub claude that always fails)
  _fail_tmp="$(mktemp -d)"
  mkdir -p "$_fail_tmp/repo/agent-loop"
  printf '# test\n' > "$_fail_tmp/repo/agent-loop/PROMPT.md"
  git -C "$_fail_tmp/repo" init -q
  git -C "$_fail_tmp/repo" -c user.email="t@t" -c user.name="T" commit --allow-empty -q -m "init"
  printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 1\n' > "$_fail_tmp/stub-fail.sh"
  chmod +x "$_fail_tmp/stub-fail.sh"
  printf 'REPO="%s/repo"\nMODE="spec"\nTEST_CMD="true"\nCLAUDE_BIN="%s/stub-fail.sh"\nMAX_ITERS=5\nMAX_CONSEC_FAILURES=2\n' \
    "$_fail_tmp" "$_fail_tmp" > "$_fail_tmp/ralph-fail.env"
  "$HERE/ralph.sh" --env "$_fail_tmp/ralph-fail.env" >/dev/null 2>&1; _fail_rc=$?
  rm -rf "$_fail_tmp"
  if [ "$_fail_rc" -ne 0 ]; then
    echo "PASS: MAX_CONSEC_FAILURES early-stop exits non-zero"
  else
    echo "FAIL: loop did not exit non-zero after MAX_CONSEC_FAILURES consecutive failures"; ok=0
  fi

  # Assert implement-mode pushes feature branch to remote, not main
  _impl_tmp="$(mktemp -d)"
  git init --bare -q "$_impl_tmp/remote.git"
  mkdir -p "$_impl_tmp/repo/agent-loop"
  printf '# test\n' > "$_impl_tmp/repo/agent-loop/PROMPT.md"
  git -C "$_impl_tmp/repo" init -q
  git -C "$_impl_tmp/repo" -c user.email="t@t" -c user.name="T" commit --allow-empty -q -m "init"
  git -C "$_impl_tmp/repo" remote add origin "$_impl_tmp/remote.git"
  _impl_repo="$_impl_tmp/repo"
  printf '#!/usr/bin/env bash\ncat >/dev/null\ngit -C "%s" checkout -b feature/stub-branch >/dev/null 2>&1\ngit -C "%s" -c user.email="t@t" -c user.name="T" commit --allow-empty -q -m "stub"\nexit 0\n' \
    "$_impl_repo" "$_impl_repo" > "$_impl_tmp/stub-impl.sh"
  chmod +x "$_impl_tmp/stub-impl.sh"
  printf 'REPO="%s"\nMODE="implement"\nTEST_CMD="true"\nCLAUDE_BIN="%s/stub-impl.sh"\nMAX_ITERS=1\nMAX_CONSEC_FAILURES=2\nREMOTE="origin"\nMAIN_BRANCH="main"\n' \
    "$_impl_repo" "$_impl_tmp" > "$_impl_tmp/ralph-impl.env"
  "$HERE/ralph.sh" --env "$_impl_tmp/ralph-impl.env" >/dev/null 2>&1
  _impl_branch_pushed=0
  _impl_main_pushed=0
  if git -C "$_impl_tmp/remote.git" branch 2>/dev/null | grep -q "feature/stub-branch"; then
    _impl_branch_pushed=1
  fi
  if git -C "$_impl_tmp/remote.git" branch 2>/dev/null | grep -q "main"; then
    _impl_main_pushed=1
  fi
  rm -rf "$_impl_tmp"
  if [ "$_impl_branch_pushed" -eq 1 ] && [ "$_impl_main_pushed" -eq 0 ]; then
    echo "PASS: implement-mode pushes feature branch, not main"
  else
    [ "$_impl_branch_pushed" -eq 0 ] && { echo "FAIL: implement-mode did not push feature branch"; ok=0; }
    [ "$_impl_main_pushed" -eq 1 ] && { echo "FAIL: implement-mode pushed main to remote"; ok=0; }
  fi

  [ "$ok" -eq 1 ] && { echo "self-test OK"; exit 0; } || exit 1
fi

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
  echo "no env file at $ENV_FILE — copy ralph.env.example to ralph.env and edit it" >&2
  exit 2
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${REPO:?REPO not set in env}"
: "${MODE:=spec}"
: "${MODEL:=claude-sonnet-4-6}"
: "${MAX_ITERS:=1}"
: "${MAX_CONSEC_FAILURES:=2}"
: "${TIME_BUDGET_SECONDS:=10800}"
: "${MAX_BUDGET_USD:=5}"
: "${COST_CEILING_USD:=20.0}"
: "${TEST_CMD:?TEST_CMD not set in env}"
: "${REMOTE:=origin}"
: "${MAIN_BRANCH:=main}"

case "$MODE" in spec|implement) ;; *) echo "MODE must be spec|implement, got '$MODE'" >&2; exit 2 ;; esac

# Resolve the claude CLI — launchd's PATH may not include ~/.local/bin. Override with CLAUDE_BIN in the env if needed.
: "${CLAUDE_BIN:=}"
if [ -z "$CLAUDE_BIN" ]; then
  if command -v claude >/dev/null 2>&1; then CLAUDE_BIN="$(command -v claude)"
  elif [ -x "$HOME/.local/bin/claude" ]; then CLAUDE_BIN="$HOME/.local/bin/claude"
  else echo "cannot find the 'claude' CLI — set CLAUDE_BIN in $ENV_FILE" >&2; exit 2; fi
fi

TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$HERE/reports/${TS}-$(basename "$REPO")-${MODE}.md"
PROGRESS="$REPO/agent-loop/progress.md"
STATE="$REPO/agent-loop/state.json"
DEADLINE=$(( $(date +%s) + TIME_BUDGET_SECONDS ))

log() { printf '%s  %s\n' "$(date +%H:%M:%S)" "$*"; [ "$DRY_RUN" -eq 0 ] && printf -- '- %s\n' "$*" >> "$REPORT" || true; }

[ "$DRY_RUN" -eq 0 ] && { mkdir -p "$HERE/reports"; {
  echo "# ralph run — $TS"
  echo
  echo "- repo: \`$REPO\`"
  echo "- mode: \`$MODE\`  model: \`$MODEL\`  max_iters: $MAX_ITERS  time_budget: ${TIME_BUDGET_SECONDS}s"
  echo
  echo "## Iterations"
} > "$REPORT"; }

cd "$REPO" || { echo "cannot cd to REPO=$REPO" >&2; exit 2; }

# ---------------------------------------------------------------------------
# Kill switch
# ---------------------------------------------------------------------------
if [ -f "$REPO/PAUSE" ]; then log "PAUSE file present at $REPO/PAUSE — exiting without doing anything"; exit 0; fi

# ---------------------------------------------------------------------------
# Sync main
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
  git -C "$REPO" fetch --quiet "$REMOTE" 2>/dev/null || log "warn: git fetch failed (no remote yet?) — continuing"
  git -C "$REPO" checkout --quiet "$MAIN_BRANCH" 2>/dev/null || log "warn: could not checkout $MAIN_BRANCH"
  git -C "$REPO" pull --quiet --ff-only "$REMOTE" "$MAIN_BRANCH" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# The instruction set for each iteration
# ---------------------------------------------------------------------------
PROMPT_BODY="$(cat "$REPO/agent-loop/PROMPT.md")"
SYS_EXTRA="MODE=$MODE. This is one iteration of a Ralph loop. Do EXACTLY ONE backlog item and then STOP — \
do not start a second item. Read agent-loop/METHOD.md and specs/README.md and agent-loop/progress.md first. \
Before concluding code does not exist, grep for it. No placeholder implementations."

# Tool allowlist for the agent. Space-separated, Claude Code permission syntax.
# Edits are auto-accepted (--permission-mode acceptEdits); these cover the Bash commands an iteration needs.
# Anything not listed gets denied — that's the guardrail; the iteration adapts or fails and is rolled back.
ALLOWED='Read Edit Write Grep Glob Bash(git *) Bash(./ralph.sh *) Bash(shellcheck *) Bash(bash -n *) Bash(ls *) Bash(cat *) Bash(rg *) Bash(gh pr *)'

ITER_LOG=""  # path to stream-json capture for current iteration; set by run_claude()

run_claude() {
  local n="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] iter $n: would run: claude -p (PROMPT.md) --model $MODEL --permission-mode acceptEdits --allowed-tools '$ALLOWED' --max-budget-usd $MAX_BUDGET_USD --output-format stream-json"
    return 0
  fi
  ITER_LOG="$(mktemp)"
  printf '%s\n' "$PROMPT_BODY" | "$CLAUDE_BIN" -p \
    --model "$MODEL" \
    --append-system-prompt "$SYS_EXTRA" \
    --permission-mode acceptEdits \
    --allowed-tools "$ALLOWED" \
    --max-budget-usd "$MAX_BUDGET_USD" \
    --output-format stream-json \
    | tee "$ITER_LOG"
}

# ---------------------------------------------------------------------------
# The loop
# ---------------------------------------------------------------------------
fails=0
did=0
session_cost_total=0
_exit_rc=0
for i in $(seq 1 "$MAX_ITERS"); do
  [ -f "$REPO/PAUSE" ]            && { log "PAUSE appeared mid-run — stopping after $did iteration(s)"; break; }
  [ "$(date +%s)" -gt "$DEADLINE" ] && { log "time budget exhausted — stopping after $did iteration(s)"; break; }

  # Session cost ceiling check (uses costs already recorded in state.json for today)
  if [ "$DRY_RUN" -eq 0 ] && command -v jq >/dev/null 2>&1 && [ -f "$STATE" ]; then
    _today="$(date +%Y%m%d)"
    _prior_cost=$(jq -r --arg p "$_today" \
      '[.runs[] | select(.ts | startswith($p)) | .cost_usd // 0] | add // 0' \
      "$STATE" 2>/dev/null || echo 0)
    _total_cost=$(awk "BEGIN{print $session_cost_total + ${_prior_cost:-0}}")
    if awk "BEGIN{exit !($_total_cost >= $COST_CEILING_USD)}"; then
      log "session cost ceiling reached ($_total_cost >= $COST_CEILING_USD) — stopping the night"
      break
    fi
  fi

  TAG="ralph-pre-iter-${TS}-${i}"
  if [ "$DRY_RUN" -eq 0 ]; then git -C "$REPO" tag -f "$TAG" >/dev/null 2>&1 || true; fi
  log "iter $i/$MAX_ITERS — start (rollback tag: $TAG)"

  run_claude "$i"; rc=$?
  did=$((did+1))

  # Parse cost from stream-json output
  iter_cost=0
  if [ "$DRY_RUN" -eq 0 ] && [ -n "$ITER_LOG" ] && [ -f "$ITER_LOG" ] && command -v jq >/dev/null 2>&1; then
    _parsed=$(jq -r 'select(.type=="result") | .cost_usd // 0' "$ITER_LOG" 2>/dev/null | tail -1)
    iter_cost="${_parsed:-0}"
    session_cost_total=$(awk "BEGIN{print $session_cost_total + $iter_cost}")
    rm -f "$ITER_LOG"
    ITER_LOG=""
  fi

  if [ "$DRY_RUN" -eq 1 ]; then continue; fi

  if [ "$rc" -ne 0 ]; then
    log "iter $i — claude exited $rc; resetting to $TAG"
    git -C "$REPO" reset --hard "$TAG" >/dev/null 2>&1 || true
    fails=$((fails+1))
  else
    log "iter $i — running back-pressure: $TEST_CMD"
    if ( cd "$REPO" && eval "$TEST_CMD" ) >>"$REPORT" 2>&1; then
      log "iter $i — back-pressure PASSED (cost this iter: \$${iter_cost})"
      fails=0
      # Record iteration cost in state.json
      if [ -f "$STATE" ] && command -v jq >/dev/null 2>&1; then
        jq --arg ts "$TS" --arg mode "$MODE" --argjson iter "$i" \
           --argjson fails "$fails" --argjson cost "${iter_cost}" \
           '.runs += [{"ts":$ts,"mode":$mode,"iter":$iter,"fails":$fails,"cost_usd":$cost}]' \
           "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE" || true
      fi
      # implement-mode: if the agent created a branch and committed, push it and open a PR. Never merge.
      cur="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
      if [ "$MODE" = "implement" ] && [ "$cur" != "$MAIN_BRANCH" ]; then
        git -C "$REPO" push -u "$REMOTE" "$cur" >>"$REPORT" 2>&1 || log "warn: push failed for $cur"
        if command -v gh >/dev/null 2>&1; then
          gh pr create --repo "$(git -C "$REPO" remote get-url "$REMOTE" 2>/dev/null)" \
            --head "$cur" --base "$MAIN_BRANCH" --fill >>"$REPORT" 2>&1 \
            && log "opened PR for $cur" || log "warn: gh pr create failed for $cur (open it manually)"
        else
          log "gh not installed — branch $cur pushed; open the PR manually"
        fi
      fi
      # spec-mode: the agent commits draft specs to main; push them so they're reviewable.
      if [ "$MODE" = "spec" ] && [ "$cur" = "$MAIN_BRANCH" ]; then
        git -C "$REPO" push "$REMOTE" "$MAIN_BRANCH" >>"$REPORT" 2>&1 \
          && log "pushed spec commit(s) to $REMOTE/$MAIN_BRANCH" || log "warn: push of $MAIN_BRANCH failed"
      fi
    else
      log "iter $i — back-pressure FAILED; resetting to $TAG"
      git -C "$REPO" reset --hard "$TAG" >/dev/null 2>&1 || true
      fails=$((fails+1))
    fi
  fi

  if [ "$fails" -ge "$MAX_CONSEC_FAILURES" ]; then
    log "hit $fails consecutive failures (limit $MAX_CONSEC_FAILURES) — stopping the night"
    break
  fi
done
if [ "$fails" -ge "$MAX_CONSEC_FAILURES" ]; then _exit_rc=1; fi

# ---------------------------------------------------------------------------
# Wrap up
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
  {
    echo
    echo "## Summary"
    echo "- iterations attempted: $did"
    echo "- consecutive failures at stop: $fails"
    echo "- mode: $MODE"
    echo "- session cost this run: \$${session_cost_total}"
    if [ "$MODE" = "implement" ]; then
      echo "- branches with un-merged PRs (review + merge these):"
      git -C "$REPO" branch --no-merged "$MAIN_BRANCH" 2>/dev/null | sed 's/^/  - /' || true
    fi
    echo
    echo "Triage: review the PR(s) above; approve good draft specs by adding their filename to specs/approved.txt."
  } >> "$REPORT"
  log "report written: $REPORT"
  [ -f "$STATE" ] || echo '{"schema":1,"runs":[]}' > "$STATE"
fi

log "done."
exit "$_exit_rc"
