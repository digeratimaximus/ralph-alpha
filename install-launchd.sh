#!/usr/bin/env bash
# install-launchd.sh — install/uninstall the nightly ralph launchd job.
#
#   ./install-launchd.sh            install (or reinstall) and load the job
#   ./install-launchd.sh --uninstall  unload and remove the job
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="com.davidmarsh.ralph"
DEST="$HOME/Library/LaunchAgents/${LABEL}.plist"
SRC="$HERE/${LABEL}.plist"

if [ "${1:-}" = "--uninstall" ]; then
  launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || launchctl unload "$DEST" 2>/dev/null || true
  rm -f "$DEST"
  echo "removed $DEST"
  exit 0
fi

[ -f "$SRC" ] || { echo "missing template $SRC" >&2; exit 1; }
[ -f "$HERE/ralph.env" ] || echo "note: $HERE/ralph.env not found yet — copy ralph.env.example to ralph.env before the first scheduled run."

mkdir -p "$HOME/Library/LaunchAgents" "$HERE/reports"
sed "s#__RALPH_DIR__#${HERE}#g" "$SRC" > "$DEST"

# (re)load
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || launchctl unload "$DEST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DEST" 2>/dev/null || launchctl load "$DEST"

echo "installed and loaded: $DEST"
echo "  runs daily at 01:00 (edit StartCalendarInterval in $SRC, then re-run this script)"
echo
echo "IMPORTANT: launchd jobs do NOT run while the Mac is asleep. To wake it just before the job:"
echo "  sudo pmset repeat wakeorpoweron MTWRFSU 00:55:00"
echo "  (check with: pmset -g sched   ·   clear with: sudo pmset repeat cancel)"
echo
echo "Test the job now without waiting for 01:00:"
echo "  launchctl kickstart -k gui/$(id -u)/${LABEL}"
echo "  tail -f $HERE/reports/launchd.err.log"
