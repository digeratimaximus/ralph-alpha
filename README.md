# ralph-alpha

A self-hosting [Ralph loop](https://ghuntley.com/ralph/): a nightly autonomous agent that
works through a backlog one item at a time, then stops. It builds and improves *itself*.

Created by David Marsh. Runs locally via `launchd` on macOS. Personal projects only.

## What a Ralph loop is

Geoffrey Huntley's technique, in one line:

```bash
while :; do cat PROMPT.md | claude -p ; done
```

Each iteration: a **fresh** agent context reads the plan, picks the single most important
unfinished item, does it, verifies against hard "back-pressure" (tests/build), commits if
green, updates the plan and progress log, exits. The repo + `specs/README.md` + `agent-loop/progress.md`
are the only memory between runs. One item per loop is the core circuit breaker.

Refs: [ghuntley.com/ralph](https://ghuntley.com/ralph/) ·
[everything is a ralph loop](https://ghuntley.com/loop/) ·
[ghuntley/how-to-ralph-wiggum](https://github.com/ghuntley/how-to-ralph-wiggum) ·
[snarktank/ralph](https://github.com/snarktank/ralph) ·
[HumanLayer: A Brief History of Ralph](https://www.humanlayer.dev/blog/brief-history-of-ralph)

## Safety model

- **Never merges. Never pushes `main`.** (Exception: spec markdown commits to `main` — they're
  useful before implementation, per `agent-loop/METHOD.md`.) Implementation work always lands as a PR you review.
- **Your gate:** the loop only *implements* a spec whose filename is listed in `specs/approved.txt`.
  You add lines to that file when you've reviewed a draft spec. The robot drafts; you approve; the robot builds; you merge.
- **Three circuit breakers:** `MAX_ITERS`, `MAX_CONSEC_FAILURES` (default 2), `TIME_BUDGET_SECONDS`.
- **Rollback:** a git tag before every iteration; a failed iteration is `git reset --hard` back to it.
- **Kill switch:** create a file named `PAUSE` at the repo root → the loop exits immediately, no iteration.
- **Tool allowlist:** runs `claude -p` with `--allowedTools`, not `--dangerously-skip-permissions`.
- **Cost:** Sonnet ≈ $10/hr. `MODEL`, `MAX_ITERS`, and `TIME_BUDGET_SECONDS` bound the spend; per-night
  estimate is appended to `agent-loop/state.json` and the morning report.

## Layout

```
ralph.sh                      # the loop
install-launchd.sh            # installs/loads the nightly launchd job
com.davidmarsh.ralph.plist    # launchd template (edit paths, then run install-launchd.sh)
ralph.env.example             # copy to ralph.env and edit; ralph.env is gitignored
agent-loop/
  PROMPT.md                   # instruction set fed to `claude -p` each iteration
  METHOD.md                   # Discuss→Spec→Implement→Verify→Ship, spec format, branch rules
  progress.md                 # append-only: what each iteration did + learned
  state.json                  # iteration count, consecutive failures, cost estimate
specs/
  README.md                   # priority-ordered backlog — the "plan file"
  approved.txt                # YOUR gate: spec filenames cleared for implement-mode
  feature-self-build.md       # seed spec
reports/                      # morning triage reports land here (gitignored contents)
```

## Run it

Manual, daylight, to start:

```bash
cp ralph.env.example ralph.env      # edit MODE, MAX_ITERS, etc.
./ralph.sh                          # uses ./ralph.env
```

Then install the nightly job:

```bash
./install-launchd.sh                # writes ~/Library/LaunchAgents/com.davidmarsh.ralph.plist and loads it
```

## Rollout

1. **Dry run, daylight, `MODE=spec`** — does it draft a sane spec in `agent-loop/METHOD.md`'s format? Tune `PROMPT.md`.
2. **Week 1:** spec mode nightly. Review each morning; approve good specs into `specs/approved.txt`. Zero risk.
3. **Week 2:** `MODE=implement`, `MAX_ITERS=1`, only tiny approved items. Review PRs — watch for placeholders, scope creep, "grepped wrong, concluded code doesn't exist."
4. **Week 3+:** `MAX_ITERS=4`. Add the cost line to the report. Point a second project's env at it if desired.
5. **Forever:** every failure mode you see → a line in `PROMPT.md`. Tune it "like a guitar."

## Gotchas

- **Headless `claude -p` with `--output-format stream-json` requires `--verbose`.** Without it the CLI
  exits 1 at arg-parse (`...stream-json requires --verbose`) *before any work runs* — so every iteration
  fails and the loop stops after `MAX_CONSEC_FAILURES`. First hit 2026-06-02, when stream-json was added
  for cost parsing without the flag. The `claude -p` invocation lives in `run_claude()` in `ralph.sh`.
