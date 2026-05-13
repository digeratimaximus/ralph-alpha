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
