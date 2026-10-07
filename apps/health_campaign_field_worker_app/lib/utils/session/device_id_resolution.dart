// Pure decisions behind DeviceIdService (which talks to the platform).
//
// Import-free on purpose so the branches are unit-testable.

const _unknown = 'unknown';

/// Returns [value] when it can identify a device; null for null, empty or the
/// platform's literal "unknown" placeholder (any case).
String? usableId(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.toLowerCase() == _unknown) return null;
  return value;
}

/// Android identifier preference: Settings.Secure.ANDROID_ID (stable per
/// device + signing key, survives reinstall) > hardware serial > build id.
/// The build id is the last resort because it is shared by every device on
/// the same firmware, which is the bug the native channel exists to fix.
String pickAndroidDeviceId({
  required String? nativeAndroidId,
  required String? serialNumber,
  required String buildId,
}) =>
    usableId(nativeAndroidId) ?? usableId(serialNumber) ?? buildId;

/// A cached id written by an older build that used the build id (or stored
/// the placeholder) must be replaced by the ANDROID_ID once available.
bool isLegacyCachedId({required String cached, required String buildId}) =>
    cached == buildId || cached.toLowerCase() == _unknown;

String fallbackId(int epochMs) => '$_unknown-$epochMs';
