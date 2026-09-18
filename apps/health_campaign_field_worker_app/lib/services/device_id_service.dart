import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../data/local_store/secure_store/secure_store.dart';

/// Resolves a stable per-device identifier used for single-active-user login
/// enforcement and logout tracking on the backend.
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
        final androidId = await _tryGetAndroidIdFromNative();
        if (androidId != null && androidId.isNotEmpty) return androidId;

        final info = await deviceInfo.androidInfo;
        if (info.serialNumber.isNotEmpty && info.serialNumber != 'unknown') {
          return info.serialNumber;
        }
        return info.id;
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
      final androidId = await _deviceIdChannel.invokeMethod<String>(
        'getAndroidId',
      );

      if (androidId == null) return null;
      if (androidId.isEmpty || androidId.toLowerCase() == 'unknown') {
        return null;
      }
      return androidId;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _migrateLegacyAndroidIdIfNeeded(String cached) async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final isLegacyBuildId = cached == info.id;
      final isUnknown = cached.toLowerCase() == 'unknown';
      if (!isLegacyBuildId && !isUnknown) return cached;

      final androidId = await _tryGetAndroidIdFromNative();
      return (androidId != null && androidId.isNotEmpty) ? androidId : cached;
    } catch (_) {
      return cached;
    }
  }

  static String _fallbackId() =>
      'unknown-${DateTime.now().millisecondsSinceEpoch}';
}
