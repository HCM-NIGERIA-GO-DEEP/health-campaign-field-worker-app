#!/usr/bin/env bash
# Drains '#PROBE#' diagnostic lines off a connected device into a file, so a
# reproduction can be handed over without the phone.
#
# This is the capture harness only. It deliberately knows NOTHING about any
# particular probe: it greps for the marker and groups whatever it finds by
# kind. An earlier version carried a per-feature verdict section for each
# probe it expected, which rotted the moment those probes were removed and
# then reported "not exercised" for every stage on every run - a confident
# wrong answer, which is worse than no answer. Add probes, capture, read the
# raw lines; keep the interpretation in the pull request, not in here.
#
# Probes are plain debugPrint lines of the shape:
#     debugPrint('#PROBE#|<kind>|key=value|key=value');
# The leading '#PROBE#|<kind>|' is the only convention this relies on.
#
# Outputs (under apps/health_campaign_field_worker_app/assets/):
#   debug-points.txt           raw #PROBE# lines from the capture
#   debug-points-summary.txt   counts per kind + the distinct lines
#
#   ./scripts/capture-debug-points.sh --check
#       Is the build on the device emitting probes at all? Answers in
#       seconds, without walking the flow. Run this FIRST - a stale APK is
#       the one failure that looks identical to "the bug did not reproduce",
#       and it has cost a full debugging round more than once. Also raises
#       the device log buffer, which matters because this app logs entire
#       JSON API responses and evicts probes within a minute otherwise.
#
#   ./scripts/capture-debug-points.sh --dump      <-- prefer this one
#       Walk the flow FIRST, hit the bug, then run this. Drains the device's
#       log buffer and exits immediately - no Ctrl-C, nothing to start
#       beforehand, and the reproduction can be one-shot. Re-runnable: each
#       dump archives the previous capture.
#
#   ./scripts/capture-debug-points.sh
#       Clears the log then follows live. Start it BEFORE entering the flow,
#       walk it, then Ctrl-C. Only worth it to watch probes stream; --dump
#       gets the same capture with less to go wrong.
#
# With more than one device attached, set ANDROID_SERIAL (see adb devices).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/apps/health_campaign_field_worker_app/assets"
OUT="$ASSETS/debug-points.txt"
SUMMARY="$ASSETS/debug-points-summary.txt"
MODE="${1:-follow}"

# Match on the marker alone. A previous version filtered on an explicit list
# of probe kinds, so every probe added afterwards was silently dropped from
# the capture and the summary then reported "not exercised" for a stage that
# had in fact run. The filter must never be the thing that decides what is
# visible.
FILTER='#PROBE#'

# Tag-agnostic: `logcat -s flutter` drops the probes on any build where the
# engine logs under a different tag (release/profile, or a device that routes
# stdout elsewhere), which is indistinguishable from "the flow never ran".
ADB=(adb)
[ -n "${ANDROID_SERIAL:-}" ] && ADB=(adb -s "$ANDROID_SERIAL")

if ! command -v adb >/dev/null; then
  echo "adb not found on PATH." >&2
  exit 1
fi

if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
  echo "No device connected (adb get-state failed)." >&2
  echo "Attached devices:" >&2
  adb devices -l >&2 || true
  echo "If more than one is listed, set ANDROID_SERIAL=<serial>." >&2
  exit 1
fi

archive_previous() {
  [ -s "$OUT" ] || return 0
  local stamp
  stamp=$(date -r "$OUT" +%Y%m%d-%H%M%S 2>/dev/null || date +%Y%m%d-%H%M%S)
  cp "$OUT" "${OUT%.txt}-$stamp.txt"
  echo "Previous capture archived to $(basename "${OUT%.txt}-$stamp.txt")"
}

summarise() {
  {
    echo "=== debug point capture ==="
    echo "captured: $(wc -l < "$OUT") line(s)"
    echo

    # Written as if/else rather than an early `return`: this block redirects
    # to $SUMMARY, and returning from inside it would skip the `cat` below,
    # so the summary would be written but never shown - silently, and
    # precisely in the empty-capture case that matters most.
    if [ ! -s "$OUT" ]; then
      echo "NOTHING CAPTURED. Narrowing down why:"
      echo

      # The ring buffer still holds the session even in follow mode
      # (following does not consume it), so these re-reads say WHICH link
      # broke instead of leaving three indistinguishable guesses.
      all_lines=$("${ADB[@]}" logcat -d 2>/dev/null | wc -l | tr -d ' ')
      flutter_lines=$("${ADB[@]}" logcat -d -s flutter 2>/dev/null | wc -l | tr -d ' ')
      any_probe=$("${ADB[@]}" logcat -d 2>/dev/null | grep -c "$FILTER" || true)

      echo "  total log lines in buffer : $all_lines"
      echo "  flutter-tagged log lines  : $flutter_lines"
      echo "  '#PROBE#' lines (any tag) : $any_probe"
      echo

      if [ "$any_probe" -gt 0 ]; then
        echo "  >> The probes ARE in the buffer but missed this capture"
        echo "     window. Re-run with --dump to drain them now."
      elif [ "$flutter_lines" -eq 0 ]; then
        echo "  >> The app logged NOTHING under the 'flutter' tag. The build"
        echo "     on the device is not the one just compiled, or the app was"
        echo "     not opened during the capture window."
      else
        echo "  >> The app IS logging but emitted no #PROBE# lines at all."
        echo "     Either this build predates the probes - rebuild AND"
        echo "     reinstall, then re-run --check - or the code paths they"
        echo "     sit on were never reached."
      fi
    else
      echo "--- probe kinds captured ---"
      # The kind is the field between the first two pipes.
      { grep -o '#PROBE#|[A-Za-z0-9_]*' "$OUT" || true; } \
        | sed 's/#PROBE#|//' | sort | uniq -c | sort -rn | sed 's/^/  /'
      echo

      echo "--- distinct lines, grouped by kind ---"
      for kind in $({ grep -o '#PROBE#|[A-Za-z0-9_]*' "$OUT" || true; } \
                      | sed 's/#PROBE#|//' | sort -u); do
        echo "  [$kind]"
        # Duplicates collapsed: a probe on a build path repeats identically
        # hundreds of times and would bury the lines that actually changed.
        { grep "|$kind|" "$OUT" || true; } \
          | sed 's/.*#PROBE#/#PROBE#/' | sort -u | sed 's/^/    /'
        echo
      done
    fi
  } > "$SUMMARY"

  cat "$SUMMARY"
  echo
  echo "Raw:     $OUT"
  echo "Summary: $SUMMARY"
}

case "$MODE" in
  --check)
    # A stale APK and a non-reproducing bug produce the same empty capture,
    # and that ambiguity has cost a whole debugging round. Answer it first.
    #
    # Raising the buffer here (the mode meant to be run first) is what makes
    # a later --dump actually hold the session: this app logs entire JSON API
    # responses, ~11k flutter lines from a single login on a Pixel 8, so the
    # default buffer evicts the probes within a minute or two of walking the
    # flow. Best effort - older devices reject -G, and it resets on reboot.
    "${ADB[@]}" logcat -G 16M >/dev/null 2>&1 \
      && echo "Log buffer raised to 16MB (survives until reboot)."
    echo "Probing the device's log buffer for #PROBE# lines..."
    kinds=$("${ADB[@]}" logcat -d 2>/dev/null \
      | grep -o '#PROBE#|[A-Za-z0-9_]*' | sort | uniq -c | sort -rn || true)
    if [ -z "$kinds" ]; then
      echo
      echo "  NO probes in the buffer."
      echo "  Either the app has not been opened since the last 'logcat -c',"
      echo "  or - far more likely - the APK on the device predates the"
      echo "  probes. Rebuild AND reinstall, open the app, re-run --check."
      exit 1
    fi
    echo
    echo "  probe kinds currently in the buffer (count, kind):"
    printf '%s\n' "$kinds" | sed 's/^/    /'
    ;;

  --dump)
    archive_previous
    : > "$OUT"
    "${ADB[@]}" logcat -d | grep -F "$FILTER" > "$OUT" || true
    summarise
    ;;

  follow)
    archive_previous
    "${ADB[@]}" logcat -G 16M >/dev/null 2>&1 || true
    "${ADB[@]}" logcat -c || true
    : > "$OUT"
    echo "Capturing probes to $OUT"
    echo "Walk the flow, then press Ctrl-C."
    echo "(If Ctrl-C ever misbehaves, kill the window and re-run with --dump"
    echo " - the device's log buffer still holds the session.)"

    # Everything below runs in the FOREGROUND on purpose.
    #
    # A previous version backgrounded this pipeline with `&` and summarised
    # from a SIGINT trap. That silently broke Ctrl-C: a non-interactive shell
    # has no job control, so POSIX has it set SIGINT to IGNORE for background
    # jobs - `adb logcat` never saw the interrupt, and killing $! only reaped
    # the `while` subshell at the tail of the pipe. The terminal printed ^C
    # and nothing else happened.
    #
    # In the foreground the pipeline members share the terminal's process
    # group, so Ctrl-C reaches them and they die on the default handler. The
    # trap here only records the interrupt so the SCRIPT survives to fall
    # through to summarise() below - it deliberately does no work itself.
    trap 'INTERRUPTED=1' INT
    INTERRUPTED=0

    # Each line gets its own write() to fd 3 before being echoed for the live
    # view. `tee -a` buffers its file output in blocks, so a capture read
    # back immediately after the interrupt looked empty while the lines
    # landed moments later - an empty verdict beside a populated .txt.
    exec 3>>"$OUT"
    "${ADB[@]}" logcat | grep --line-buffered -F "$FILTER" | while IFS= read -r line; do
      printf '%s\n' "$line" >&3
      printf '%s\n' "$line"
    done || true
    exec 3>&-

    [ "$INTERRUPTED" -eq 1 ] && echo
    summarise
    ;;

  *)
    echo "Unknown mode: $MODE (expected no argument, --dump or --check)" >&2
    exit 1
    ;;
esac
