/// Measures how long a CDD spends on one administration: from entry to the
/// delivery screen until the delivery task is submitted.
///
/// Both timestamps are device-local epoch millis taken at the moment of the
/// action, so a record made offline carries the offline moment through sync.
/// A monotonic stopwatch runs alongside the wall clock; when the two
/// disagree at submit, the device clock was changed mid-administration and
/// the record is flagged rather than stored as a trusted duration.
class AdministrationTimer {
  AdministrationTimer({DateTime Function()? now, Stopwatch? stopwatch})
      : _now = now ?? DateTime.now,
        _stopwatch = stopwatch ?? Stopwatch();

  static final AdministrationTimer instance = AdministrationTimer();

  /// Largest gap allowed between the wall-clock and stopwatch durations
  /// before the record is flagged as having had its clock changed.
  static const Duration clockDriftTolerance = Duration(seconds: 60);

  static const String negativeDurationFlag = 'NEGATIVE_DURATION';
  static const String clockChangedFlag = 'CLOCK_CHANGED';

  final DateTime Function() _now;
  final Stopwatch _stopwatch;
  int? _startTime;

  /// Starts timing an administration and returns its start time. Runs on
  /// every entry to the delivery screen, so leaving without submitting and
  /// coming back restarts the clock.
  int start() {
    _startTime = _now().millisecondsSinceEpoch;
    _stopwatch
      ..reset()
      ..start();
    return _startTime!;
  }

  /// The administration's end time: the moment of submission.
  int end() => _now().millisecondsSinceEpoch;

  /// The flag for an administration that started at [startTime] and is
  /// being submitted now, or null when its duration can be trusted.
  ///
  /// The stopwatch is only compared when it was started for this same
  /// administration; otherwise only a negative duration is caught.
  String? flag(int startTime) {
    final elapsed =
        startTime == _startTime ? _stopwatch.elapsedMilliseconds : null;
    return flagFor(
      startTime: startTime,
      endTime: end(),
      elapsedMillis: elapsed,
    );
  }

  static String? flagFor({
    required int startTime,
    required int endTime,
    int? elapsedMillis,
  }) {
    if (endTime < startTime) return negativeDurationFlag;
    if (elapsedMillis != null &&
        (endTime - startTime - elapsedMillis).abs() >
            clockDriftTolerance.inMilliseconds) {
      return clockChangedFlag;
    }
    return null;
  }
}
