# Self-build: harden the Ralph harness

status: draft

## What
Bring `ralph.sh` and its support files from "scaffolded" to "trustworthy enough to run unattended nightly":
exit codes correct everywhere, `--self-test` actually covers the failure modes that have bitten us, `--dry-run`
prints an accurate plan, the implement-mode PR path works end to end, and the `claude -p` invocation matches the
installed Claude Code CLI.

## Why
The loop's first job is to be safe to run while David sleeps. Everything downstream (launchd, multi-project,
cost tracking) depends on the core loop being reliable and on its back-pressure command being meaningful.

## Approach
- Audit `run_claude()` against the installed `claude` CLI: confirm `--allowedTools`, `--append-system-prompt`,
  `--max-turns`, `--model` are the right flag names; if not, fix them. Consider `--output-format json` so cost
  can be parsed later (item 4).
- Make `--self-test` assert: `bash -n` clean; `shellcheck -S warning` clean (skip gracefully if shellcheck absent);
  required files present; `ralph.env.example` parses; `--dry-run` exits 0 against a throwaway env.
- Make `--dry-run` print, per iteration, the exact `claude -p` command line and the back-pressure command, without
  calling claude, without writing a report, without creating tags.
- Verify the rollback path: a deliberately-failing iteration must `git reset --hard` to its `ralph-pre-iter-*` tag
  and increment the failure counter; `MAX_CONSEC_FAILURES` must stop the night.
- Verify the implement-mode tail: if HEAD is a non-`main` branch after a passing iteration, push it and (if `gh`
  is available and authed) open a PR; never merge; never push `main`.

## Tests
Extend `./ralph.sh --self-test` with the assertions above. Add a `--dry-run` smoke invocation to it.

## Verification
- `./ralph.sh --self-test` exits 0.
- `./ralph.sh --dry-run --env ralph.env.example` prints a plausible plan and exits 0, touching nothing.
- A scratch run with a stub "claude" on PATH that just `exit 1`s shows the rollback + failure-count + early stop behavior.

## Progress
- [x] Audit & fix `claude -p` flags  — done 2026-05-12 (removed nonexistent `--max-turns`; added `--permission-mode acceptEdits`, `--max-budget-usd`; `--allowedTools`→`--allowed-tools`)
- [ ] Flesh out `--self-test` assertions
- [ ] Make `--dry-run` fully side-effect-free and accurate
- [ ] Verify rollback + failure-count + MAX_CONSEC_FAILURES with a stub claude
- [ ] Verify implement-mode push/PR tail (no merge, no main push)
