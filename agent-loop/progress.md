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
