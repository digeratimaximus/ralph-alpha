# System: tool allowlist audit

status: draft

## What
Audit and correct `ALLOWED` in `ralph.sh` and the guidance in `PROMPT.md` so they are mutually
consistent. Add `TodoWrite` to `ALLOWED` (task tracking is benign; the Claude Code base system
prompt advises it on every run). Remove the "use sub-agents freely" sentence from `PROMPT.md`,
since `Agent` is deliberately absent from `ALLOWED` — sub-agents spawn with unconstrained
permissions and would undermine the safety model.

## Why
Two contradictions currently exist:

1. The Claude Code base system prompt tells each agent iteration to use `TodoWrite` for task
   tracking, but `TodoWrite` is not in `ALLOWED`. Any iteration that tries to track tasks gets
   a denied-tool error for a completely routine operation.

2. `PROMPT.md` says "use sub-agents freely for reading/searching/grepping," but `Agent` is not
   in `ALLOWED`. If we added it, sub-agents would run with the default (unconstrained) tool set,
   bypassing the allowlist — which defeats the purpose of having one.

The fix is to add `TodoWrite` (safe) and update `PROMPT.md` to tell agents to search directly
with `Grep`, `Glob`, and `Read` instead of spawning sub-agents.

## Approach
1. In `ralph.sh`, append `TodoWrite` to the `ALLOWED` variable.
2. In `agent-loop/PROMPT.md`, replace "Use sub-agents freely for reading/searching/grepping"
   with: "Search directly with `Grep`, `Glob`, and `Read` — sub-agents are not available in
   this context (not in the tool allowlist)."
3. No other changes needed — the safety model is correct; the docs and config are inconsistent.

Affected files: `ralph.sh`, `agent-loop/PROMPT.md`.

## Tests
Add one `--self-test` assertion: `grep -q 'TodoWrite' "$HERE/ralph.sh"` (verifies the variable
definition contains it). Cheap and dependency-free.

## Verification
- `./ralph.sh --self-test` exits 0
- `grep ALLOWED ralph.sh` shows `TodoWrite` in the value
- `grep -i 'sub-agent' agent-loop/PROMPT.md` returns nothing (or shows the corrected text)

## Progress
- [ ] Add `TodoWrite` to `ALLOWED` in `ralph.sh`
- [ ] Update sub-agent guidance in `agent-loop/PROMPT.md`
- [ ] Add `--self-test` assertion that ALLOWED contains `TodoWrite`
