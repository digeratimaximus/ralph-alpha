#!/usr/bin/env bash
# Creates a minimal regression fixture repo at $1 (the directory must already exist).
# Called by ./ralph.sh --regression-test before each sub-run.
set -euo pipefail

FIXTURE_DIR="${1:?Usage: setup-fixture.sh <fixture-dir>}"

git -C "$FIXTURE_DIR" init -q
git -C "$FIXTURE_DIR" config user.email "ralph-test@example.com"
git -C "$FIXTURE_DIR" config user.name "Ralph Test"

mkdir -p "$FIXTURE_DIR/agent-loop" "$FIXTURE_DIR/specs"

cat > "$FIXTURE_DIR/agent-loop/PROMPT.md" <<'EOF'
# Fixture PROMPT.md
This is a fixture prompt for regression testing.
EOF

cat > "$FIXTURE_DIR/agent-loop/METHOD.md" <<'EOF'
# Fixture METHOD.md
Minimal stub for regression testing.
EOF

cat > "$FIXTURE_DIR/agent-loop/progress.md" <<'EOF'
# Progress log (fixture)
EOF

printf '{"schema":1,"runs":[]}\n' > "$FIXTURE_DIR/agent-loop/state.json"

cat > "$FIXTURE_DIR/specs/README.md" <<'EOF'
# Backlog (fixture)
| # | Item | Track | Spec | Status |
|---|---|---|---|---|
| 1 | Test item | feature | `feature-test.md` | draft spec |
EOF

printf 'feature-test.md\n' > "$FIXTURE_DIR/specs/approved.txt"

cat > "$FIXTURE_DIR/specs/feature-test.md" <<'EOF'
# Test feature

status: approved

## What
A fixture spec for regression testing.

## Progress
- [ ] Implement test feature
EOF

git -C "$FIXTURE_DIR" add -A
git -C "$FIXTURE_DIR" commit -q -m "fixture: initial state"
