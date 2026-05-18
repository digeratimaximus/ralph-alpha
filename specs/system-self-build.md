# System: harden the Ralph harness

status: draft

## What
Bring `ralph.sh` and its support files from "scaffolded" to trustworthy enough to run unattended
nightly: `--self-test` covers the real failure modes; `--dry-run` is fully side-effect-free;
rollback/failure-count/early-stop are verified with a stub claude; and the implement-mode push+PR
tail is confirmed to never merge and never push main.

## Why
The loop's first job is to be safe while David sleeps. Everything downstream (launchd, multi-project,
cost tracking) depends on the core loop being reliable and on `--self-test` being meaningful as the
back-pressure gate.

## Approach
**Already done (2026-05-12):** `run_claude()` flags audited against installed Claude Code 2.1.140
(`--max-turns` removed; `--permission-mode acceptEdits`, `--max-budget-usd`, `--allowed-tools` added).

**Remaining work (all in `ralph.sh`):**

1. **`--self-test` additions** — beyond current syntax + file checks, assert:
   - `ralph.env.example` is source-able (`bash -c "source ralph.env.example"` succeeds or the file
     has only comments/no-ops — skip if it deliberately has unset vars, use `set +u` for the check)
   - `--dry-run` exit 0 smoke: create a throwaway env pointing at a scratch dir, run
     `./ralph.sh --dry-run --env <tmp.env>`, assert exit 0 with no files written to `reports/`
   - `MAX_CONSEC_FAILURES` / early-stop: use a stub-claude that always `exit 1`; assert the loop
     stops after `MAX_CONSEC_FAILURES` consecutive failures and exits non-zero

2. **`--dry-run` hardening** — verify no side effects:
   - No report file written
   - No git tags created
   - No `git push` called
   - Current implementation looks correct; add assertions to `--self-test` to confirm

3. **Implement-mode push/PR tail** — add a `--self-test` smoke that, with a stub-claude that
   creates a branch and exits 0, confirms `push` is called for that branch and `main` is not pushed.
   (Can be asserted without an actual remote by capturing the git push command via `GIT_TRACE`.)

## Tests
All new checks are assertions inside `--self-test` so they run as the back-pressure gate.

## Verification
- `./ralph.sh --self-test` exits 0
- `./ralph.sh --dry-run --env ralph.env.example` exits with a message (no `REPO` set) — that's fine;
  the smoke test inside `--self-test` uses a proper tmp env
- After implementation, the three new assertion groups each emit a labeled PASS/FAIL line

## Progress
- [x] Audit & fix `claude -p` flags (done 2026-05-12)
- [ ] Add `--self-test` assertion: ralph.env.example source-able
- [ ] Add `--self-test` assertion: `--dry-run` smoke (no files written)
- [ ] Add `--self-test` assertion: stub-claude always-fail → loop stops at MAX_CONSEC_FAILURES
- [ ] Add `--self-test` assertion: implement-mode stub → push branch, not main
