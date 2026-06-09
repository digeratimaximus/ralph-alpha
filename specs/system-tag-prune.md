# System: pre-iteration git tag pruning

status: approved → implemented

## What
Add a `prune_old_tags()` function to `ralph.sh` that deletes all but the most recent
`TAG_KEEP` (default 20) `ralph-pre-iter-*` tags from the local repository. Called once
per run in the wrap-up block.

## Why
Each iteration creates one `ralph-pre-iter-*` rollback tag. Tags older than the current
night's run are never needed again. At `MAX_ITERS=4`, that's ~120 new tags per month,
making `git log --decorate` and `git tag -l` increasingly noisy with no benefit.

## Approach
1. Add `: "${TAG_KEEP:=20}"` to the config defaults block in `ralph.sh` (after the other
   `:`-style defaults).
2. Add `prune_old_tags()` function: lists `ralph-pre-iter-*` tags sorted oldest-first via
   `git tag -l 'ralph-pre-iter-*' | sort`, counts them, and deletes all but the last
   `$TAG_KEEP` using `git tag -d`.
3. In the wrap-up block, call `prune_old_tags` guarded by `[ "$DRY_RUN" -eq 0 ]`.
4. Add `TAG_KEEP=20` (commented) to `ralph.env.example` with a one-line comment.
5. Add a `--self-test` assertion: `grep -q 'prune_old_tags' "$HERE/ralph.sh"`.

Affected files: `ralph.sh`, `ralph.env.example`. No new files.

## Tests
One `--self-test` assertion:
```bash
grep -q 'prune_old_tags' "$HERE/ralph.sh" || { echo "FAIL: prune_old_tags missing from ralph.sh"; ok=0; }
```

## Verification
- `./ralph.sh --self-test` exits 0
- Manual: create 25 scratch tags (`git tag ralph-pre-iter-scratch-{01..25}`), call
  `prune_old_tags` directly (source ralph.sh functions in a test shell), confirm
  exactly 20 remain and the oldest 5 are gone
- `./ralph.sh --dry-run` does not call `prune_old_tags` (log shows no prune line)

## Progress
- [x] Add `TAG_KEEP` default to config block in `ralph.sh`
- [x] Add `prune_old_tags()` function to `ralph.sh`
- [x] Call `prune_old_tags` in wrap-up block (dry-run guarded)
- [x] Add `TAG_KEEP=20` (commented) to `ralph.env.example`
- [x] Add `--self-test` assertion for `prune_old_tags` presence
