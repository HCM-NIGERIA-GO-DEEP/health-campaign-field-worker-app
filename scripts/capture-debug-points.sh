#!/usr/bin/env bash
# Captures ONLY the SLDBG instrumentation lines from the app and packages into
# apps/health_campaign_field_worker_app/assets/debug-points.txt.
#
# Works regardless of how the app was launched (IDE debug session, flutter
# run, or a debug APK installed by hand) because Flutter's debug prints all
# land in logcat under the "flutter" tag.
#
#   ./scripts/capture-debug-points.sh
#       Clears the log, then follows live. Start it BEFORE doing the flow;
#       Ctrl-C when finished.
#
#   ./scripts/capture-debug-points.sh --dump
#       Drains what is already in the logcat ring buffer and exits. Use when
#       you did the flow first. The buffer is finite - do it soon after.
set -euo pipefail

OUT="$(cd "$(dirname "$0")/.." && pwd)/apps/health_campaign_field_worker_app/assets/debug-points.txt"
MODE="${1:-follow}"

if ! command -v adb >/dev/null; then
  echo "adb not found on PATH." >&2
  exit 1
fi

# Both modes overwrite $OUT. Keep the previous capture rather than destroying
# it - a run that has already been analysed is not reproducible, and losing
# one to an accidental re-run costs a whole repro cycle.
archive_previous() {
  [ -s "$OUT" ] || return 0
  local stamp
  stamp=$(date -r "$OUT" +%Y%m%d-%H%M%S 2>/dev/null || date +%Y%m%d-%H%M%S)
  cp "$OUT" "${OUT%.txt}-$stamp.txt"
  echo "Previous capture archived to $(basename "${OUT%.txt}-$stamp.txt")"
}

case "$MODE" in
  --dump)
    archive_previous
    : > "$OUT"
    adb logcat -d -s flutter | grep "SLDBG" > "$OUT" || true
    count=$(wc -l < "$OUT")
    echo "Wrote $count SLDBG lines to $OUT"
    [ "$count" -eq 0 ] && echo "Nothing captured - wrong build, or lines aged out of the buffer." >&2
    ;;
  follow)
    archive_previous
    adb logcat -c
    : > "$OUT"
    echo "Capturing SLDBG lines to $OUT"
    echo "Run the flow on the device now. Press Ctrl-C when done."
    adb logcat -s flutter | grep --line-buffered "SLDBG" | tee -a "$OUT"
    ;;
  *)
    echo "Unknown mode: $MODE (expected no argument, or --dump)" >&2
    exit 1
    ;;
esac
