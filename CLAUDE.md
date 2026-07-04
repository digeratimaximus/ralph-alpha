# ralph-alpha — project context

Adds to `~/.claude/CLAUDE.md` (identity/style/prefs live there — not repeated).

**What it is:** Self-hosting Ralph loop — a nightly autonomous agent (launchd 01:00, DMS-1) that works one backlog item per iteration, then stops. It builds and improves *itself*. Personal projects only.

**Run / test:**
- Loop: `./ralph.sh` (uses `./ralph.env`) · `--projects-dir projects.d` runs each `*.env` sequentially (skips `*.disabled`).
- `--dry-run` prints what each iteration would do, never calls claude, never writes. Use this first.
- `--self-test` is the self-hosting `TEST_CMD` (lint + sanity, exit 0 if healthy). `--regression-test` replays fixtures asserting safety invariants. **Run one of these before committing loop changes.**

**Hard rules:**
- **Never leave `main` committed-but-unpushed.** The loop commits `MAIN_BRANCH` locally without pushing; unpushed commits cause drift that rebuilds every run. Push, or work on a branch + PR. (PR #12 → main is canonical; local-main was archived 07-03.)
- The loop **never merges and never pushes `MAIN_BRANCH`** (spec markdown excepted) — don't add code that does.
- Memory between runs is only the repo + `specs/README.md` + `agent-loop/progress.md`. One item per loop is the core circuit breaker — preserve it.
- Safety scaffolding is load-bearing: per-iteration git-tag rollback, `PAUSE` kill switch, `MAX_ITERS` / `MAX_CONSEC_FAILURES` / `TIME_BUDGET_SECONDS`. Don't weaken to "make it finish."
