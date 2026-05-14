# Backlog — ralph-alpha

Priority-ordered. This is the loop's plan file. Highest priority at the top.
A spec file in `specs/` means the item has been specced; the filename appearing in `specs/approved.txt` means it's cleared for implement-mode.

| # | Item | Track | Spec | Status |
|---|---|---|---|---|
| 1 | **Self-build**: implement `ralph.sh` (loop, tags, back-pressure, PR), `--self-test`, `--dry-run` to a working, lint-clean state | system | `system-... (tbd)` — partial draft exists as `feature-self-build.md`, re-spec properly | scaffolded, needs hardening |
| 2 | **launchd install**: `install-launchd.sh` writes + loads `~/Library/LaunchAgents/com.davidmarsh.ralph.plist`; prints `pmset` wake hint; supports `--uninstall` | system | `system-launchd-install.md` | draft spec |
| 3 | **Morning report**: richer `reports/<ts>-<repo>-<mode>.md` — diff stat per iteration, list of new draft specs awaiting approval, cost estimate, link to PRs | feature | `feature-morning-report.md` | draft spec |
| 4 | **Cost tracking**: parse `claude -p` usage output (or `--output-format json`) and append a real `cost_estimate_usd` to `agent-loop/state.json`; abort the night if a running total exceeds `COST_CEILING_USD` | system | `system-cost-tracking.md` | draft spec |
| 5 | **Multi-project support**: `projects.d/*.env`; `ralph.sh` iterates enabled project envs sequentially; per-project reports | system | — | not specced |
| 6 | **PROMPT.md regression harness**: a way to replay a fixed repo state through one iteration and assert the agent picked the right item / didn't touch `main` / produced a spec in the right format | feature | — | not specced |
| 7 | **Notification**: on run completion, post the summary somewhere David sees it in the morning (file is fine; email/Slack optional) | feature | — | not specced |

## Notes

- Items 1 is the bootstrap target — the loop should harden its own harness first.
- Don't reorder existing items without recording why in `agent-loop/progress.md`.
- When this list grows unwieldy, an iteration in spec mode may re-groom it instead of adding a new spec.
