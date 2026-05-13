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
- `claude -p` flag names (`--allowedTools`, `--append-system-prompt`, `--max-turns`, `--model`) — verify against the installed Claude Code version; adjust `run_claude()` in `ralph.sh` if they've changed.
- `gh` may not be authenticated on this machine yet — implement-mode pushes the branch regardless, but PR creation will warn and you'll open the PR by hand until `gh auth login` is done.
- launchd jobs don't run while the Mac is asleep — `install-launchd.sh` prints the `pmset` hint; actually run it.
