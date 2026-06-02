# Feature: morning report enrichment

status: approved

## What
After each iteration, ralph.sh appends richer structured data to the run report
(`reports/<ts>-<repo>-<mode>.md`): per-iteration diff stat, a list of draft specs
not yet in `specs/approved.txt`, a real cost figure from the claude output, and PR
URLs opened during the run.

## Why
The current report logs timestamps and pass/fail outcomes but nothing the human
needs to triage the morning after: what changed, which specs need a review decision,
how much the run cost, and what PRs are waiting. Without those, every morning starts
with a manual `git log` + `gh pr list` + mental accounting.

## Approach
All changes live in `ralph.sh` (the wrap-up and per-iter sections); no new files.

**Per-iteration diff stat** — after back-pressure passes (line ~160 in ralph.sh),
append `git diff --stat HEAD~1 HEAD 2>/dev/null || true` to the report. Guard with
`git rev-parse HEAD~1 >/dev/null 2>&1` so an initial commit doesn't blow up.

**Draft specs awaiting approval** — in the wrap-up block, compare `specs/*.md` (minus
`specs/README.md`) against the filenames in `specs/approved.txt`. Emit a markdown list
of the unapproved ones under an `## Action required` heading.

**Cost figure** — read `cost_usd` for the current run from `agent-loop/state.json`
(populated by the cost-tracking feature, `system-cost-tracking.md`). Write a
`cost_usd: <value>` line to the report. If the field is absent (cost-tracking not
yet implemented), omit the line — do **not** attempt independent stderr capture,
which conflicts with cost-tracking's `--output-format stream-json` approach.

*Dependency: `system-cost-tracking.md` should be implemented before this feature
for the cost line to appear. The other three sections (diff stat, unapproved specs,
PR links) are fully independent of cost-tracking.*

**PR links** — when `gh pr create` succeeds, capture its stdout (the PR URL) and
append it to the report under `## PRs opened`.

Affected file: `ralph.sh` only.

## Tests
In `./ralph.sh --self-test`:
- Verify the `--dry-run` path still produces a report skeleton (no errors on stderr).
- `bash -n ralph.sh` already covers syntax; shellcheck covers style.

The report content itself is validated by the morning-after human reading it — no
automated assertion for formatting, only for crash-free execution.

## Verification
1. Run `./ralph.sh --dry-run`; confirm no bash errors.
2. Run `./ralph.sh --self-test`; confirm exit 0.
3. After a real spec-mode run: open the report and confirm it contains:
   - A `## Diff` section per iteration with file counts.
   - An `## Action required` section listing unapproved specs (or "none").
   - A `cost_usd` line (only if cost-tracking is also implemented).
   - A `## PRs opened` section (empty in spec-mode; populated in implement-mode).

## Progress
- [x] Per-iteration diff stat appended after back-pressure passes
- [x] Unapproved-specs list in wrap-up section
- [x] Cost line in report — read from state.json (requires system-cost-tracking)
- [x] PR URL capture from `gh pr create` stdout
- [x] `--self-test` and `--dry-run` still pass
