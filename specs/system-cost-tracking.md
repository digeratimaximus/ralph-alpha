# Cost tracking

status: draft

## What

After each iteration, extract the actual API cost from the claude CLI output and record it in `agent-loop/state.json`. Before starting each new iteration, check the session's cumulative cost against a configurable ceiling (`COST_CEILING_USD`) and stop the loop early if the ceiling is reached.

## Why

Currently `state.json` is initialised but never populated with real cost data — the loop has no way to know what a night actually cost. The only limit today is per-iteration (`--max-budget-usd`), not per-session. A session running `MAX_ITERS=6` at $5 each could spend $30 with no ceiling. Cost tracking gives a real audit trail and a session-level safety net.

## Approach

**Capturing cost from the claude CLI**

Use `--output-format stream-json` instead of the current default. With `stream-json`, the claude CLI emits one JSON event per line to stdout; the final event is a `result` record that includes `cost_usd`. Streaming output remains live (each event is emitted as it arrives), so the report gets real-time output and the final cost can be extracted by scanning the last `result` event with `jq`.

Implementation sketch inside `run_claude()`:
1. Run claude with `--output-format stream-json`, piping stdout through `tee "$ITER_LOG"` so the stream is visible in the terminal and also captured.
2. After claude exits, parse cost: `jq -r 'select(.type=="result") | .cost_usd // 0' "$ITER_LOG" | tail -1`.
3. Return the cost to the caller via a global or temp file (bash functions can't return floats; write to `$ITER_COST_FILE`).

**state.json schema** (extend existing):

```json
{
  "schema": 1,
  "runs": [
    {"ts": "20260514-020000", "mode": "spec", "iters": 1, "fails": 0, "cost_usd": 0.12}
  ]
}
```

**Files changed**: `ralph.sh` only, plus `ralph.env.example` (new `COST_CEILING_USD` var).

**Session cost gate**: at the top of each loop iteration, sum `cost_usd` from `state.json` runs whose `ts` starts with today's date prefix, compare to `COST_CEILING_USD`, and break if over.

## Tests

Extend `--self-test`:
- Assert `COST_CEILING_USD` default is documented in `ralph.env.example`.
- Assert `state.json` parses as valid JSON (`python3 -m json.tool` or `jq .`).
- Assert `state.json` contains the `runs` key.

## Verification

1. Run `./ralph.sh --dry-run` — must exit 0 with no change in behaviour (dry-run skips claude call, no cost written).
2. After a real spec-mode iteration, inspect `agent-loop/state.json` — the latest run entry must have a non-zero `cost_usd`.
3. Set `COST_CEILING_USD=0.0001` in `ralph.env` and run a two-iteration job — the second iteration must be skipped with a log line like `session cost ceiling reached`.

## Progress

- [ ] Add `COST_CEILING_USD` to `ralph.env.example` (default `20.0`)
- [ ] Switch `run_claude()` to `--output-format stream-json`; tee to temp log
- [ ] Parse `cost_usd` from temp log after each iteration
- [ ] Append run entry (ts, mode, iters, fails, cost_usd) to `state.json` after each iteration
- [ ] Check cumulative session cost before each iteration; break if over ceiling
- [ ] Extend `--self-test` with cost-tracking assertions
