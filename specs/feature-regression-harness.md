# PROMPT.md regression harness

status: draft

## What
A `tests/regression/` directory with fixture repo state and stub-claude scripts, plus a `./ralph.sh --regression-test` flag that replays one canned spec-mode and one canned implement-mode iteration, then asserts invariants (right item chosen, `main` not mutated by implement-mode, spec has correct format).

## Why
The loop runs unattended at night. The only way to trust a harness change doesn't silently break a safety invariant (e.g. agent commits to `main` in implement-mode, or rollback fails) is a repeatable test that doesn't require a live LLM call.

## Approach

**Fixtures** — `tests/regression/fixture-repo/` is a minimal git repo created once by a setup script (`tests/regression/setup-fixture.sh`):
- An `agent-loop/` tree with `PROMPT.md`, `METHOD.md`, `progress.md`, `state.json`.
- A `specs/` tree with `README.md`, `approved.txt` (containing one entry), and one approved spec file.
- Two stub-claude scripts: `stub-spec-claude.sh` and `stub-implement-claude.sh`. Each is invoked in place of the real `claude` CLI; it reads from stdin (the prompt) and performs the git ops a real agent would do (write a new spec and commit to main; or create a branch, write a file, commit).
- A minimal `ralph.env` pointing at the fixture repo, with `CLAUDE_BIN` set to the appropriate stub, and `TEST_CMD=true`.

**`--regression-test` flag in `ralph.sh`** — runs setup-fixture, then:
1. Spec-mode run: assert back-pressure passed, a `specs/*.md` file was added, HEAD is on `main`.
2. Implement-mode run: assert back-pressure passed, HEAD is on a feature branch (not `main`), `main` branch itself has no new commits.

Tear down fixture repo after each sub-run to isolate.

**Affected files:** `ralph.sh` (add `--regression-test` branch), `tests/regression/setup-fixture.sh`, `tests/regression/stub-spec-claude.sh`, `tests/regression/stub-implement-claude.sh`.

## Tests
`./ralph.sh --self-test` gains one new assertion: `./ralph.sh --regression-test` exits 0. That in turn is the regression gate.

## Verification
- `./ralph.sh --regression-test` exits 0 and prints `regression-test OK`.
- `./ralph.sh --self-test` exits 0 (transitively runs the regression test).
- Delete `tests/regression/stub-spec-claude.sh` and confirm `--regression-test` exits non-zero.

## Progress
- [ ] Write `tests/regression/setup-fixture.sh`
- [ ] Write `tests/regression/stub-spec-claude.sh` and `stub-implement-claude.sh`
- [ ] Add `--regression-test` flag to `ralph.sh`
- [ ] Add regression assertion to `--self-test`
