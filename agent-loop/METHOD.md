# Working method — ralph-alpha

Adapted from David's `process.md`. This is how work moves through this repo, whether a human or the loop is doing it.

## The loop

Every work item: **Discuss → Spec → Implement → Verify → Ship.**

- **Discuss** — human (or, for autonomous nights, the backlog in `specs/README.md`) describes the change: what, why. For the nightly loop, "Discuss" already happened when the item was written into the backlog.
- **Spec** — for anything spanning more than one iteration or touching more than one file: a spec under `specs/`. Small self-contained changes (single file, well under an hour) can skip the spec and just go in the commit message. **The human approving a spec — by adding its filename to `specs/approved.txt` — is the gate.** Nothing gets implemented by the loop without that.
- **Implement** — code follows the approved spec. Stays scoped to the current item. Update the spec's `Progress` checkboxes as tasks complete.
- **Verify** — run the back-pressure command (`./ralph.sh --self-test`, plus anything the spec's `Verification` section names). It must pass. No "looks fine" — run it.
- **Ship** — commit. Spec docs commit to `main` immediately (useful before implementation). Implementation lands on a branch as a **PR** the human merges. The loop never merges and never pushes `main`.

## Spec format

One markdown file per work item, in `specs/`. No sub-folders unless an item is genuinely large. Keep it to one screen.

**Naming:** `specs/feature-<short-name>.md` (behavior/capability) or `specs/system-<short-name>.md` (harness/infra/safety).

**Template** (use only the sections that apply):

```markdown
# Title

status: draft        # draft → approved (human adds filename to specs/approved.txt) → shipped

## What
One paragraph: what this change does.

## Why
One paragraph: the problem it solves.

## Approach
How it'll be built. Key decisions and trade-offs. Affected files.

## Tests
What check to add — usually: extend `./ralph.sh --self-test` or add a check it runs.

## Verification
Manual steps / commands / expected output to confirm it works end-to-end.

## Progress
- [ ] Task 1
- [ ] Task 2
```

## Branch strategy

| Branch | When |
|---|---|
| `main` | spec docs (always, immediately), and trivial single-diff doc/typo fixes |
| `feature/<name>` | a feature/capability change implemented by the loop or a human |
| `system/<name>` | a harness / infra / safety change |

Branch is created at spec sign-off (filename added to `specs/approved.txt`). PRs required for `feature/` and `system/`. Human merges after reviewing the diff. The loop opens PRs; it does not merge them.

## Backlog

`specs/README.md` is the single priority-ordered index of work items. New items go in at the right priority; don't reorder existing ones without saying why in `agent-loop/progress.md`.

## Testing / back-pressure

Every item that adds behavior includes a check, committed alongside it. For this repo the check is almost always: a new assertion inside `./ralph.sh --self-test`, or a script that command runs. `./ralph.sh --self-test` must exit 0 before Ship. The nightly harness re-runs it after each iteration as the back-pressure gate; a failing iteration is rolled back via its pre-iteration git tag.
