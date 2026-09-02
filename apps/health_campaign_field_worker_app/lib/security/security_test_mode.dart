/// Whether this build was produced for the `tools/security` verification
/// scripts, via `--dart-define=SECURITY_TEST_MODE=true`.
///
/// Defaults to false, so a normal or release build is never affected.
///
/// A shipped build deliberately makes detection *unobservable from outside*:
/// [AppSecurityFeature.debugPrintSuppression] silences `debugPrint`, and a
/// confirmed threat terminates the process. Both are correct for production and
/// both defeat black-box verification — the line the scripts grep for never
/// reaches logcat, and the process is gone before anything else could report
/// it. That combination is what made the root-detection tests report
/// VULNERABLE on an emulator while detection was in fact firing.
///
/// A build with this flag set keeps every check running and every threat
/// confirmed, but leaves the evidence visible: logs stay on and the response
/// mode becomes [ThreatResponseMode.reportOnly].
///
/// It must never be set for a build that ships.
const bool kSecurityTestMode = bool.fromEnvironment('SECURITY_TEST_MODE');
