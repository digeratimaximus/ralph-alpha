# Ralph iteration prompt — ralph-alpha

You are continuing work on the **ralph-alpha** repo. This is **one iteration** of a Ralph loop.
You will do **exactly one** backlog item, verify it, record it, and **stop**. Do not start a second item.

## Read these first, every iteration (your only memory between runs)

1. `agent-loop/METHOD.md` — the working method: Discuss → Spec → Implement → Verify → Ship, the spec format, the branch rules. Follow it.
2. `specs/README.md` — the priority-ordered backlog. This is your plan.
3. `specs/approved.txt` — which spec files are cleared for implementation (the human's gate).
4. `agent-loop/progress.md` — what previous iterations already did. **Do not repeat work.**
5. `README.md` — what ralph-alpha is and its safety model.

`MODE` is provided in the system prompt as `MODE=spec` or `MODE=implement`.

---

## If MODE=spec

Goal: turn the next backlog item into a reviewable spec. **You do not implement anything in spec mode.**

1. From `specs/README.md`, pick the **highest-priority** item that does **not** yet have a spec file in `specs/`.
2. Write `specs/feature-<short-name>.md` or `specs/system-<short-name>.md` (per the naming rules in `agent-loop/METHOD.md`), using the spec format in `agent-loop/METHOD.md`. Keep it to **one screen** — a spec that fits without scrolling beats a long one. Include a `status: draft` line near the top.
3. Add the new spec to `specs/README.md` in the right priority position (do not reorder existing items).
4. Append a dated line to `agent-loop/progress.md`: which item, the spec filename, anything you learned or that the human should know.
5. Commit **to the current branch (main)** with a message like `spec: <title>`. Spec docs are allowed on main — they're useful before implementation.
6. **Stop.** Do not implement. Do not create a feature branch.

---

## If MODE=implement

Goal: implement the next **approved** spec, on a branch, verified, as a PR. **You never merge. You never commit non-spec changes to `main`.**

1. From `specs/README.md`, pick the **highest-priority** item whose spec filename appears in `specs/approved.txt` and whose `Progress` checkboxes are not all checked (i.e. not yet shipped).
   - If no approved item is available: append a note to `agent-loop/progress.md` saying so, and **stop**. Do not invent work.
2. Create the branch per `agent-loop/METHOD.md`'s branch table: `feature/<short-name>` or `system/<short-name>`, from `main`.
3. Implement **strictly to the approved spec**. No scope creep — if you discover adjacent work, note it in `agent-loop/progress.md` and leave it for a future item.
   - **No placeholder implementations.** If you cannot fully implement the item this iteration, revert your changes (`git reset --hard`) and either pick a smaller approved item or stop. A half-done placeholder is worse than nothing.
   - Before assuming a function/file/feature does not exist: **grep for it.** Concluding code is missing when it isn't is the #1 Ralph failure mode.
4. Add or update tests/checks as the spec's `Tests` section requires. For this repo that usually means: extend `./ralph.sh --self-test`, or add a check it runs.
5. Verify: run `./ralph.sh --self-test` (and anything else the spec's `Verification` section names). It must exit 0. The harness will also re-run the back-pressure command after you finish — but don't rely on that; verify yourself first.
6. Update the spec's `Progress` checkboxes. Update `agent-loop/progress.md` with a dated line: item, branch, what changed, what worked, what to watch out for next time.
7. Commit (you write the message — concise, imperative). The harness pushes the branch and opens the PR; you do **not** push to `main` and do **not** merge.
8. **Stop.** One item.

---

## Always

- Use sub-agents freely for reading/searching/grepping. Use **at most one** sub-agent at a time for running tests/builds — concurrent validation causes failures.
- Keep `specs/README.md` and `agent-loop/progress.md` accurate; they're the loop's memory.
- If `specs/README.md` has grown unwieldy or stale, it's fine to spend an iteration (in spec mode) re-grooming it instead of adding a new spec — note that you did so.
- If you find the repo in a broken state from a previous iteration, fixing that **is** a legitimate one-item iteration. Say so in `progress.md`.
- Never touch anything outside this repo. Never run destructive git commands beyond `reset --hard` to your own iteration's tag.
