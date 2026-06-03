# Progress log — ralph-alpha

Append-only. One dated entry per iteration: what item, what changed, what worked, what to watch next time.
This is the loop's memory between runs — keep it honest and specific.

---

## 2026-05-12 — bootstrap (human + Claude, by hand)

Scaffolded the repo: `ralph.sh` (the loop, with `--dry-run` and `--self-test`), `install-launchd.sh`,
`com.davidmarsh.ralph.plist`, `agent-loop/{PROMPT.md,METHOD.md,progress.md,state.json}`,
`specs/{README.md,approved.txt,feature-self-build.md}`, `ralph.env.example`, `.gitignore`.

State: harness exists but is **un-exercised**. `specs/README.md` has the initial backlog. `specs/approved.txt`
is empty — nothing is cleared for implement-mode yet. Next: run `./ralph.sh --dry-run` to sanity-check, then a
real `MODE=spec` run to draft the first specs, then a human reviews them.

Watch-outs for future iterations:
- launchd jobs don't run while the Mac is asleep — `install-launchd.sh` prints the `pmset` hint; actually run it.
- `--allowed-tools` patterns use Claude Code permission syntax (`Bash(git *)` etc.); if an iteration keeps failing because it can't run a command it needs, widen `ALLOWED` in `ralph.sh` (deliberately narrow for now).

## 2026-05-12 — flag audit (human + Claude, by hand)

Audited `run_claude()` against installed Claude Code `2.1.140`. Findings: there is **no `--max-turns`** flag in
this version — removed it. Added `--permission-mode acceptEdits` (auto-accept edits; non-allowlisted Bash still
denied) and `--max-budget-usd $MAX_BUDGET_USD` (per-iteration API spend cap, default $5; new `MAX_BUDGET_USD` in
`ralph.env.example`). Switched `--allowedTools` → `--allowed-tools` with space-separated permission-syntax patterns.
`gh` is now authenticated as `digeratimaximus` and the repo is pushed to `origin/main`. Covers spec
`feature-self-build.md` task "Audit & fix `claude -p` flags". `--self-test` and `--dry-run` still pass.

## 2026-05-12 — spec: launchd install (MODE=spec, Ralph loop)

Item 2 from the backlog. Wrote `specs/system-launchd-install.md`. The `install-launchd.sh` and
`com.davidmarsh.ralph.plist` are already scaffolded and functional; the spec defines what hardening
and `--self-test` assertions are needed to trust them. Updated `specs/README.md` to link the spec.

## 2026-05-13 — spec: morning report (MODE=spec, Ralph loop)

Item 3 from the backlog. Wrote `specs/feature-morning-report.md`. All changes will land in `ralph.sh`
only — no new files. Key decisions: capture claude stderr for cost via temp file; diff stat is gated on
`git rev-parse HEAD~1` to survive an initial commit; unapproved-spec list is computed by diffing
`specs/*.md` against `specs/approved.txt`. Updated `specs/README.md` to link the spec.

Watch-outs for implementation: stderr redirection on the `claude -p` call needs care — the current
invocation pipes stdin and captures nothing from stderr; implementation will need `2>$tmpfile` while
keeping stdout live to the terminal/report.

## 2026-05-14 — spec: cost tracking (MODE=spec, Ralph loop)

Item 4 from the backlog. Wrote `specs/system-cost-tracking.md`. Key design decision: use
`--output-format stream-json` rather than capturing stderr — stream-json emits one JSON event per
line including a final `result` event with `cost_usd`, while keeping output live. Implementation
will tee stdout to a temp log, parse cost with jq after the iteration, and append a run entry to
`state.json`. New `COST_CEILING_USD` env var (default 20.0) checked before each iteration to stop
the session if cumulative spend exceeds the ceiling. Updated `specs/README.md` to link the spec.

Watch-outs for implementation:
- `--output-format stream-json` changes the output format; verify the morning report's report
  capture still works correctly (may need to strip JSON envelope when writing to the report file).
- Session cost gate sums runs from state.json by today's date prefix — if a run spans midnight
  the prefix check will miss earlier runs; acceptable limitation for a nightly job.

## 2026-05-15 — spec: multi-project support (MODE=spec, Ralph loop)

Item 5 from the backlog. Wrote `specs/system-multi-project.md`. Key design: extract the current
single-env run body into a `run_project()` function, add `--projects-dir <dir>` flag that iterates
over `*.env` files in that directory (skipping `*.disabled`). Shared `DEADLINE` across all projects.
Each project already gets its own report via `basename "$REPO"` in the filename. Updated
`specs/README.md` to link the spec.

Watch-outs for implementation:
- The refactor into `run_project()` touches the entire body of ralph.sh below "Load config" —
  careful to keep all variable references correct (DEADLINE, REPORT, etc.) when they move into a
  function scope vs top-level scope.
- `--dry-run` and `--self-test` flags both need to work correctly when `--projects-dir` is set;
  verify each combination in the Verification steps.

## 2026-05-16 — spec: regression harness (MODE=spec, Ralph loop)

Item 6 from the backlog. Wrote `specs/feature-regression-harness.md`. Key design: a
`tests/regression/` directory with a setup script that builds a minimal fixture git repo and two
stub-claude scripts (spec-mode and implement-mode variants). A new `--regression-test` flag in
`ralph.sh` runs each stub-claude variant against the fixture repo and asserts invariants (spec
committed to main, implement-mode landed on a branch not main). `--self-test` gains an assertion
that `--regression-test` exits 0. Updated `specs/README.md` to link the spec.

Watch-outs for implementation:
- The stub-claude scripts read from stdin (the prompt piped by ralph.sh) — they must consume
  stdin fully or ralph.sh's pipe will hang; use `cat >/dev/null` at the top.
- Fixture repo teardown must happen even on failure so stale fixture state doesn't poison
  subsequent runs; use a `trap` in the `--regression-test` block.
- The fixture `ralph.env` must set `TEST_CMD=true` (not the real `./ralph.sh --self-test`)
  to avoid recursive self-test invocations.

## 2026-05-18 — spec: re-spec self-build as system-self-build.md (MODE=spec, Ralph loop)

Item 1 from the backlog (re-spec). Wrote `specs/system-self-build.md` to replace the bootstrap
draft `feature-self-build.md` with a proper `system-*` spec. The flags audit (2026-05-12) is marked
done; remaining work is three groups of `--self-test` assertions covering dry-run side-effects,
MAX_CONSEC_FAILURES early-stop (with a stub claude), and implement-mode push/PR tail. Updated
`specs/README.md` to reference the new spec; `feature-self-build.md` is superseded but left in
place (the loop never deletes files without explicit approval).

Watch-outs for implementation:
- The `MAX_CONSEC_FAILURES` stub-claude test needs a throwaway git repo and env file; tear it down
  in a `trap` so stale state doesn't leak between self-test runs.
- The implement-mode push assertion using `GIT_TRACE` captures verbose output — parse conservatively
  (check for the branch name in the trace, not exact command format which may vary by git version).

## 2026-05-17 — spec: run-completion notification (MODE=spec, Ralph loop)

Item 7 from the backlog. Wrote `specs/feature-notification.md`. Design: a `notify_done()`
helper in `ralph.sh` that calls `osascript` to post a macOS Notification Center alert with
iteration count, failure count, cost estimate, and report path. Guard with `command -v
osascript` so it silently no-ops on non-macOS. Updated `specs/README.md` to link the spec.

Watch-outs for implementation:
- The cost variable (`COST_EST`) may not exist until the cost-tracking feature lands;
  use `${COST_EST:-?}` so the notification is still useful when cost capture is absent.
- `osascript` strings need careful escaping — avoid double-quotes inside the message body
  or escape them as `\"`.
- This is the last unspecced backlog item. After this, all 7 items have draft specs;
  the loop can be re-groomed or implementation can begin on approved items.

## 2026-05-19 — re-groom: fix morning-report/cost-tracking conflict (MODE=spec, Ralph loop)

Backlog re-groom. All 7 specs were already drafted; this iteration fixed a design conflict
and added implementation-order guidance.

**Conflict fixed**: `feature-morning-report.md` previously described capturing cost via
stderr grep (`$ X.XXXX`), which is mutually exclusive with cost-tracking's
`--output-format stream-json` approach. The morning-report spec now reads cost from
`agent-loop/state.json` (populated by cost-tracking) and explicitly states it must not
attempt independent stderr capture. The `Progress` checkbox was updated to reflect this.

**README.md additions**: added an "Implementation order and dependencies" section noting:
- approve system-self-build first (back-pressure gate)
- approve system-cost-tracking before feature-morning-report (cost data dependency)
- approve system-multi-project last (full ralph.sh refactor, high conflict risk)
- items 2, 6, 7 are independent

No new spec created — the re-groom was the right call for this iteration.

## 2026-05-20 — spec: tool allowlist audit (MODE=spec, Ralph loop)

All 7 existing backlog items already had draft specs. Found a genuine new item:
`ALLOWED` in `ralph.sh` is missing `TodoWrite` (the Claude Code base system prompt tells every
agent iteration to use it for task tracking — omitting it causes denied-tool errors for routine
ops). Separately, `PROMPT.md` says "use sub-agents freely" but `Agent` is not in `ALLOWED` and
shouldn't be (sub-agents bypass the allowlist, weakening the safety model).

Wrote `specs/system-allowlist.md`. Inserted as new item 2 in `specs/README.md` (existing items
2–7 renumbered to 3–8; recorded here as required). Updated the implementation-order notes to
reflect 8 specs and the new dependency.

Watch-outs for implementation:
- The `ALLOWED` variable is a single-line string; append `TodoWrite` with a space separator.
- Update the sub-agent sentence in `agent-loop/PROMPT.md` carefully — the existing wording is
  in the "Always" section at the bottom; replace only that sentence, not the whole section.
- The `--self-test` assertion uses grep on the `ralph.sh` source file itself — straightforward
  but make sure the grep pattern is specific enough to not false-positive on a comment.

## 2026-05-21 — spec: pre-iteration git tag pruning (MODE=spec, Ralph loop)

All 8 existing backlog items already had draft specs. Identified a genuine new item: each
iteration creates a `ralph-pre-iter-*` rollback tag that is never pruned. At MAX_ITERS=4,
that accumulates ~120 tags/month with no cleanup mechanism.

Wrote `specs/system-tag-prune.md` as item 9 (lowest priority — maintenance-only, approve
last). Key design: `prune_old_tags()` function in `ralph.sh`, called at wrap-up guarded by
`DRY_RUN=0`; keeps most recent `TAG_KEEP` (default 20) tags; `TAG_KEEP` in `ralph.env.example`.
Updated `specs/README.md` count from 8 to 9 and added item 9 to the approval-order notes.

Watch-outs for implementation:
- `git tag -l 'ralph-pre-iter-*' | sort` sorts lexicographically; the timestamp format
  (YYYYMMDD-HHMMSS) sorts correctly as-is, so no `--sort` flag needed.
- `git tag -d` is local-only; the remote won't have these tags (ralph.sh never pushes
  tags via `git push --tags`), so no remote deletion needed.
- The `--self-test` assertion is just a grep for the function name — simple and dependency-free.

## 2026-05-22 — spec: all 9 backlog items already specced (MODE=spec, Ralph loop)

All 9 backlog items already have draft spec files; no unspecced item remains to pick. Backlog
was last groomed 2026-05-21. Nothing has been approved yet — the loop is waiting for the human
to add filenames to `specs/approved.txt` before any implement-mode iteration can begin.

Suggested approval order (from specs/README.md):
1. `system-self-build.md` and `system-allowlist.md` first (back-pressure gate + allowlist fix)
2. `system-cost-tracking.md` before `feature-morning-report.md` (data dependency)
3. `system-multi-project.md` last (full ralph.sh refactor, high conflict risk)
4. `system-launchd-install.md`, `feature-regression-harness.md`, `feature-notification.md`,
   `system-tag-prune.md` are independent and can be approved in any order.

No spec written this iteration — there was nothing to spec.

## 2026-05-23 — spec: still waiting for human approval (MODE=spec, Ralph loop)

All 9 backlog items have draft spec files; `specs/approved.txt` remains empty. No new spec to
write and no re-groom needed. Loop is idle until the human approves at least one spec file.

No spec written this iteration — loop is blocked on human approval gate.

## 2026-05-24 — spec: still waiting for human approval (MODE=spec, Ralph loop)

All 9 backlog items have draft spec files; `specs/approved.txt` remains empty. No new spec to
write and no re-groom needed. Loop is idle until the human approves at least one spec file.

No spec written this iteration — loop is blocked on human approval gate.

## 2026-05-25 — implement: system-self-build (branch: system/self-build)

First implement-mode iteration. All 9 specs were approved by David 2026-05-25.
Implemented `specs/system-self-build.md` (item 1) — the three remaining `--self-test` assertions plus
an exit-code fix.

Changes to `ralph.sh`:
- Added 4 new `--self-test` assertion groups, each emitting PASS/FAIL:
  1. `ralph.env.example` is source-able (`bash -c "set +u; source ralph.env.example"`)
  2. `--dry-run` smoke: launches a sub-invocation against a tmp repo, asserts exit 0 and no files
     written to `reports/`
  3. `MAX_CONSEC_FAILURES` early-stop: uses a stub claude that always exits 1; asserts the loop
     exits non-zero after hitting the consecutive failure limit
  4. Implement-mode push: uses a stub claude that creates a feature branch; asserts the branch is
     pushed to a local bare remote and `main` is not pushed
- Fixed exit code: the loop now exits 1 when `MAX_CONSEC_FAILURES` is reached (previously exited 0).
  Added `_exit_rc` variable set after the loop body, `exit "$_exit_rc"` at end of script.

`./ralph.sh --self-test` exits 0 with all four PASS lines.

Watch-outs for next iterations:
- The stub tests create real reports in `reports/` during the fail/impl tests (those stubs are
  not dry-run). Minor side effect — acceptable.
- The implement-mode test uses a local bare repo as "remote"; `gh pr create` fails (just a warn).
  That warning is intentional and harmless.

## 2026-06-03 — verify: system-self-build (branch: system/self-build, PR opened)

Item 1 (`system-self-build.md`) — highest-priority approved item not yet shipped.

Found `system/self-build` branch already existed with all five Progress checkboxes checked (implemented
2026-05-25). Switched to branch, ran `./ralph.sh --self-test`: all four PASS lines emitted, exits 0.

Updated spec status from `draft` to `approved → implemented`. Opened PR.

Next iteration should verify `system/allowlist` (item 2) — branch `system/allowlist` already exists.
