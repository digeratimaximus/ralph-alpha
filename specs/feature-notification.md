# Feature: run-completion notification

status: draft

## What
At the end of each `ralph.sh` session (success or failure), post a macOS Notification
Center alert so David sees "Ralph ran — N iters, $X.XX, report at …" when he opens his
Mac in the morning. No new runtime dependencies required.

## Why
The morning report file lands in `reports/`, but there is no push signal — David must
remember to look for it. A persistent Notification Center alert surfaces the outcome
passively, removing the "did it even run?" mental check from the morning triage.

## Approach
Add a `notify_done()` helper at the top of `ralph.sh`. It accepts a short message string
and posts it via `osascript`:

```bash
notify_done() {
  local msg="$1"
  osascript -e "display notification \"$msg\" with title \"Ralph\" sound name \"Glass\""
}
```

Call it once at the very end of the session wrap-up (after the report is written), with a
one-line summary built from already-available variables:

```
"N iters | M failed | est $X.XX | report: reports/<file>"
```

`ITERS_DONE`, `CONSEC_FAILURES`, and `COST_EST` (populated by the cost-tracking feature,
or `"?"` when absent) are substituted into the message. If `osascript` is not available
(non-macOS) the call is silently skipped via `command -v osascript >/dev/null 2>&1`.

No new files. Affected file: `ralph.sh` only.

## Tests
In `./ralph.sh --self-test`:
- `bash -n ralph.sh` (already present) covers syntax.
- Confirm `notify_done` is defined: `grep -q "notify_done()" ralph.sh`.

Functional correctness is verified manually (notification appears on screen).

## Verification
1. `./ralph.sh --self-test` exits 0.
2. Run `./ralph.sh --dry-run`; a "Ralph" notification appears in Notification Center
   within a few seconds.
3. Verify the notification body contains iteration count and "report:" path.

## Progress
- [ ] `notify_done()` helper added to `ralph.sh`
- [ ] Called at end of session wrap-up with summary string
- [ ] `osascript` availability guard in place
- [ ] `--self-test` confirms `notify_done` is defined and `bash -n` passes
