# Backlog — ralph-alpha

Priority-ordered. This is the loop's plan file. Highest priority at the top.
A spec file in `specs/` means the item has been specced; the filename appearing in `specs/approved.txt` means it's cleared for implement-mode.

| # | Item | Track | Spec | Status |
|---|---|---|---|---|
| 1 | **Self-build**: harden `ralph.sh` — `--self-test` covers real failure modes, `--dry-run` fully side-effect-free, rollback/failure-count verified, implement-mode push/PR tail confirmed | system | `system-self-build.md` | draft spec (supersedes `feature-self-build.md`) |
| 2 | **launchd install**: `install-launchd.sh` writes + loads `~/Library/LaunchAgents/com.davidmarsh.ralph.plist`; prints `pmset` wake hint; supports `--uninstall` | system | `system-launchd-install.md` | draft spec |
| 3 | **Morning report**: richer `reports/<ts>-<repo>-<mode>.md` — diff stat per iteration, list of new draft specs awaiting approval, cost estimate, link to PRs | feature | `feature-morning-report.md` | draft spec |
| 4 | **Cost tracking**: parse `claude -p` usage output (or `--output-format json`) and append a real `cost_estimate_usd` to `agent-loop/state.json`; abort the night if a running total exceeds `COST_CEILING_USD` | system | `system-cost-tracking.md` | draft spec |
| 5 | **Multi-project support**: `projects.d/*.env`; `ralph.sh` iterates enabled project envs sequentially; per-project reports | system | `system-multi-project.md` | draft spec |
| 6 | **PROMPT.md regression harness**: a way to replay a fixed repo state through one iteration and assert the agent picked the right item / didn't touch `main` / produced a spec in the right format | feature | `feature-regression-harness.md` | draft spec |
| 7 | **Notification**: on run completion, post the summary somewhere David sees it in the morning (file is fine; email/Slack optional) | feature | `feature-notification.md` | draft spec |

## Notes

- Item 1 is the bootstrap target — the loop should harden its own harness first.
- Don't reorder existing items without recording why in `agent-loop/progress.md`.
- When this list grows unwieldy, an iteration in spec mode may re-groom it instead of adding a new spec.

## Implementation order and dependencies

All 7 specs are drafted (2026-05-19). None are yet approved. Suggested approval order:

1. **Item 1 first** (`system-self-build.md`) — the back-pressure gate underpins everything else.
2. **Item 4 before Item 3** (`system-cost-tracking.md` before `feature-morning-report.md`) — morning-report reads cost from `state.json` populated by cost-tracking; the cost line is omitted until cost-tracking lands.
3. **Item 5 last** (`system-multi-project.md`) — refactors the entire body of `ralph.sh`; approve after items 1 and 4 are merged to minimise conflicts.
4. **Items 2, 6, 7** are independent and can be approved in any order once item 1 is done.

Conflict resolved (2026-05-19 re-groom): `feature-morning-report.md` previously described capturing cost via stderr grep, which conflicts with cost-tracking's `--output-format stream-json`. The morning-report spec now reads cost from `state.json` only.
