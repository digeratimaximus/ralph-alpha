# System: launchd install/uninstall

status: draft

## What
`install-launchd.sh` writes a templated plist to `~/Library/LaunchAgents/com.davidmarsh.ralph.plist`,
loads it with `launchctl`, prints the `pmset` wake hint, and supports `--uninstall`. The script and
plist template are already scaffolded; this item hardens and tests them.

## Why
The launchd job is how Ralph runs unattended every night. If the install/uninstall path is broken or
the plist has wrong paths, the whole loop fails silently. We need `--self-test` to catch regressions.

## Approach
- `install-launchd.sh` already: substitutes `__RALPH_DIR__` and `__HOME__` into the plist, calls
  `launchctl bootstrap` (falling back to `load`), prints the `pmset` hint and a `kickstart` test command.
- `--uninstall` already: calls `bootout`/`unload`, removes the installed plist.
- Hardening tasks:
  - Add `bash -n install-launchd.sh` and `bash -n com.davidmarsh.ralph.plist` (skip latter — XML, not sh)
    to `--self-test`; add `shellcheck -S warning install-launchd.sh` (skip if absent).
  - Verify the plist template is valid XML: `xmllint --noout com.davidmarsh.ralph.plist 2>/dev/null || plutil -lint`.
  - Smoke-test `--uninstall` when the job is not loaded (should exit 0, not crash).
  - `--self-test` must NOT actually invoke `launchctl` or `pmset` — those are side-effectful. Confine them to
    the real install/uninstall code paths.

## Tests
In `./ralph.sh --self-test`:
- `bash -n install-launchd.sh` exits 0.
- `shellcheck -S warning install-launchd.sh` exits 0 (skip if shellcheck absent).
- `xmllint --noout com.davidmarsh.ralph.plist` exits 0 (or `plutil -lint` fallback).
- Template contains the string `__RALPH_DIR__` (i.e. install-launchd.sh hasn't accidentally baked in a
  hardcoded path into the template).

## Verification
1. `./ralph.sh --self-test` exits 0 and includes the launchd checks in its output.
2. `./install-launchd.sh` on a dev machine installs and loads the job without error; `launchctl list | grep ralph`
   shows it loaded.
3. `./install-launchd.sh --uninstall` removes `~/Library/LaunchAgents/com.davidmarsh.ralph.plist` and
   exits 0; running again also exits 0 (idempotent).
4. `./install-launchd.sh --uninstall` on a machine that never ran the install exits 0 (no crash).

## Progress
- [x] Add `bash -n`, `shellcheck`, and `xmllint`/`plutil` checks to `--self-test`
- [x] Verify plist template still has `__RALPH_DIR__` placeholder (not baked in)
- [ ] Manual install + uninstall verification on dev machine
