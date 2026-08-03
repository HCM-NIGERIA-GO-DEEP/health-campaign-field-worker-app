/// Campaign working-hours window evaluation (device-local wall clock).
///
/// Deliberately import-free pure Dart (like `team_qr_codec.dart`) so its unit
/// tests compile standalone even when unrelated lib files are broken.
///
/// Contract: NOTHING in this library throws. The consumer is a flow-builder
/// `fn:` callback, and an uncaught throw inside any `fn:` blanks the whole
/// TEMPLATE screen body. Every input is `dynamic` because unquoted config
/// arguments can resolve to arbitrary context values (null, List, Map, ...).
///
/// Per-bound resolution chain:
///   1. config value ('HH:mm' argument from the flow JSON)
///   2. hardcoded campaign default ([defaultStart] / [defaultEnd])
///   3. full-day safety net 00:00-24:00 (always allowed) — unreachable through
///      the public API since tier 2 always parses, but kept explicit so a
///      future edit to the defaults cannot introduce a blocked-forever state.
library;

class WorkingHours {
  WorkingHours._();

  /// Tier 2 — hardcoded app defaults, used when a config value is
  /// missing or unparseable.
  static const String defaultStart = '07:00';
  static const String defaultEnd = '17:00';

  /// Tier 3 — ultimate safety net: the full-day window (always allowed).
  static const int safetyNetStartMinutes = 0; // 00:00
  static const int safetyNetEndMinutes = 1440; // 24:00

  static final RegExp _hhMm = RegExp(r'^(\d{1,2}):(\d{2})$');

  /// Parses 'HH:mm' / 'H:mm' into minutes-of-day [0..1440].
  /// Accepts '24:00' as 1440 (end-of-day). Returns null for anything
  /// malformed (wrong type, out of range, missing colon). Never throws.
  static int? parseHhMm(dynamic raw) {
    if (raw is! String) return null;
    final match = _hhMm.firstMatch(raw.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour == 24) return minute == 0 ? 1440 : null;
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  /// True iff [nowMinutesOfDay] falls inside the window. Never throws.
  ///
  /// Each bound falls back independently: unparseable start -> [defaultStart],
  /// unparseable end -> [defaultEnd]. Window rules:
  ///  - start == end            -> allowed (degenerate; disabling the gate is
  ///                               done by removing the condition from config)
  ///  - start < end (normal)    -> start <= now && now < end (half-open)
  ///  - start > end (overnight) -> now >= start || now < end
  static bool isWithinWindow(
      dynamic startRaw, dynamic endRaw, int nowMinutesOfDay) {
    final start =
        parseHhMm(startRaw) ?? parseHhMm(defaultStart) ?? safetyNetStartMinutes;
    final end =
        parseHhMm(endRaw) ?? parseHhMm(defaultEnd) ?? safetyNetEndMinutes;
    if (start == end) return true;
    if (start < end) {
      return nowMinutesOfDay >= start && nowMinutesOfDay < end;
    }
    return nowMinutesOfDay >= start || nowMinutesOfDay < end;
  }

  /// Convenience for the fn: wrapper: evaluates the window against the
  /// device-local wall clock of [now]. Never throws.
  static bool isWithinWindowAt(dynamic startRaw, dynamic endRaw, DateTime now) {
    return isWithinWindow(startRaw, endRaw, now.hour * 60 + now.minute);
  }
}
