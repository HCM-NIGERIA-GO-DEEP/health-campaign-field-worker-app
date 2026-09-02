/// Filesystem indicators used by the Dart-side fallback checks.
///
/// These intentionally mirror the equivalent lists in
/// `android/app/src/main/kotlin/com/digit/hcm/SecurityHelper.kt`. The
/// duplication is defence in depth: if the native library is stripped or its
/// channel is unreachable, these still run. Update both sides together.
class KnownIndicators {
  const KnownIndicators._();

  /// Binaries and packages that indicate a rooted device.
  static const List<String> rootPaths = [
    '/system/app/Superuser.apk',
    '/system/xbin/su',
    '/system/bin/su',
    '/sbin/su',
    '/system/su',
    '/system/bin/.ext/.su',
    '/system/xbin/busybox',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/data/local/su',
  ];

  /// Artefacts left by hooking frameworks.
  static const List<String> hookPaths = [
    '/data/local/tmp/frida-server',
    '/data/local/tmp/re.frida.server',
    '/system/lib/libfrida-gadget.so',
    '/system/lib64/libfrida-gadget.so',
    '/system/xbin/frida-server',
  ];
}
