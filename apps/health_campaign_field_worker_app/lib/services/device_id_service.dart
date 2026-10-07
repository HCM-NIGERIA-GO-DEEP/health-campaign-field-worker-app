import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../data/local_store/secure_store/secure_store.dart';
import '../utils/session/device_id_resolution.dart';

/// Resolves a stable per-device identifier used for single-active-user login
/// enforcement and logout tracking on the backend.
///
/// Ported from itn-mc-base (9a2ba2480). The id is cached in secure storage
/// and survives logout; on Android it is Settings.Secure.ANDROID_ID read over
/// a MethodChannel (MainActivity.kt), which is stable per device + signing
/// key and survives reinstall, so a reinstalled app is still "the same
/// device" to the backend. The pure decisions live in
/// device_id_resolution.dart so they stay unit-testable.
class DeviceIdService {
  static const MethodChannel _deviceIdChannel =
      MethodChannel('com.digit.hcm/device_id');

  static Future<String> getDeviceId() async {
    final cached = await LocalSecureStore.instance.deviceId;
    if (cached != null && cached.isNotEmpty) {
      if (Platform.isAndroid) {
        final migrated = await _migrateLegacyAndroidIdIfNeeded(cached);
        if (migrated != cached) {
          await LocalSecureStore.instance.setDeviceId(migrated);
        }
        return migrated;
      }
      return cached;
    }

    final id = await _resolveDeviceId();
    await LocalSecureStore.instance.setDeviceId(id);
    return id;
  }

  static Future<String> _resolveDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final nativeId = usableId(await _tryGetAndroidIdFromNative());
        if (nativeId != null) return nativeId;

        final info = await deviceInfo.androidInfo;
        return pickAndroidDeviceId(
          nativeAndroidId: null,
          serialNumber: info.serialNumber,
          buildId: info.id,
        );
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.identifierForVendor ?? _fallbackId();
      }
      return _fallbackId();
    } catch (_) {
      return _fallbackId();
    }
  }

  static Future<String?> _tryGetAndroidIdFromNative() async {
    try {
      return await _deviceIdChannel.invokeMethod<String>('getAndroidId');
    } catch (_) {
      return null;
    }
  }

  /// A cached build id (written when the native channel was unavailable) or a
  /// cached placeholder is replaced by the ANDROID_ID once it can be read.
  static Future<String> _migrateLegacyAndroidIdIfNeeded(String cached) async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (!isLegacyCachedId(cached: cached, buildId: info.id)) return cached;

      return usableId(await _tryGetAndroidIdFromNative()) ?? cached;
    } catch (_) {
      return cached;
    }
  }

  static String _fallbackId() =>
      fallbackId(DateTime.now().millisecondsSinceEpoch);
}
