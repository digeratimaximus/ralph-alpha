#!/usr/bin/env bash
# Stub claude for implement-mode regression test.
# Called by ralph.sh in place of the real claude CLI. Simulates an implement-mode agent:
# consumes stdin (the prompt), creates a feature branch, commits there, and exits 0.
# Never commits to main. All CLI flags passed by ralph.sh are ignored.
cat > /dev/null  # consume stdin to avoid SIGPIPE in the caller's pipe

set -euo pipefail

git config user.email "ralph-test@example.com"
git config user.name "Ralph Test"

git checkout -q -b "feature/stub-test"
printf 'stub implementation output\n' > "stub-output.txt"
git add stub-output.txt
git commit -q -m "implement: stub test feature"
