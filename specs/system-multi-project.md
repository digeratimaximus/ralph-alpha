# Multi-project support

status: approved → implemented

## What

Add a `--projects-dir <dir>` flag to `ralph.sh`. When set, ralph reads all `*.env` files in that directory (sorted lexically; files ending `.disabled` skipped) and runs one sequential project session per env file. Each project gets its own report. A top-level summary lists outcomes.

## Why

Currently ralph-alpha targets a single repo, configured once at startup. As David adds more repos to the nightly loop the only way to cover them is separate launchd jobs — one per repo — each with independent circuit breakers and no shared time budget. Multi-project support fans the loop out from one job without changing the launchd setup.

## Approach

**Flag:** `--projects-dir <dir>` (can be combined with `--dry-run` or `--self-test`).

**projects.d/ layout:**

```
projects.d/
  ralph-alpha.env    # enabled
  my-app.env         # enabled
  old-thing.env.disabled  # skipped
```

Each `*.env` file has the same variables as `ralph.env` (`REPO`, `MODE`, `MODEL`, `MAX_ITERS`, etc.). They do not need to set every variable — defaults apply after sourcing.

**Code change:** Extract the body of ralph.sh from "Load config" to "Wrap up" into a function `run_project()` that takes an env-file path as its only argument. The top-level script calls it once (single-env case) or in a `for` loop (projects-dir case). The overall `DEADLINE` is set once before the loop and passed down — all projects share the time budget.

**Affected files:** `ralph.sh` only. `ralph.env.example` gets a short `# Multi-project` comment block.

**Report:** each project already gets its own `reports/<ts>-<repo>-<mode>.md` (path uses `basename "$REPO"`). The outer run appends a summary section listing projects, iteration counts, and failure counts.

## Tests

Extend `--self-test`: if `projects.d/` exists and contains `*.env` files, verify each is bash-parseable (`bash -n <file>`). Fail the self-test if any file fails.

## Verification

1. Create `projects.d/test-a.env` pointing at the ralph-alpha repo. Run `./ralph.sh --projects-dir projects.d/ --dry-run` — expect one `[dry-run] project: test-a.env` line.
2. Add `projects.d/test-b.env.disabled` — rerun; confirm only `test-a.env` is processed.
3. `./ralph.sh --self-test` still exits 0.

## Progress

- [x] Extract `run_project()` from current single-env body
- [x] Add `--projects-dir` flag parsing; iterate `*.env` (skip `*.disabled`)
- [x] Set shared `DEADLINE` once before the outer loop
- [x] Write outer summary section to top-level report
- [x] Extend `--self-test` for projects.d/ validation
- [x] Add multi-project comment block to `ralph.env.example`
- [x] Update `specs/README.md` and `agent-loop/progress.md`
