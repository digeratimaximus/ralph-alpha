#!/usr/bin/env bash
# Stub claude for spec-mode regression test.
# Called by ralph.sh in place of the real claude CLI. Simulates a spec-mode agent:
# consumes stdin (the prompt), writes a new draft spec to main, and exits 0.
# All CLI flags passed by ralph.sh (--model, --allowed-tools, etc.) are ignored.
cat > /dev/null  # consume stdin to avoid SIGPIPE in the caller's pipe

set -euo pipefail

git config user.email "ralph-test@example.com"
git config user.name "Ralph Test"

cat > "specs/feature-new-spec.md" <<'EOF'
# New spec (stub-generated)

status: draft

## What
Stub-generated spec for regression testing.

## Progress
- [ ] Task 1
EOF

printf '\n## stub spec-mode — new spec written\n\nStub committed a new draft spec.\n' \
  >> "agent-loop/progress.md"

git add specs/feature-new-spec.md agent-loop/progress.md
git commit -q -m "spec: stub-generated draft spec"
