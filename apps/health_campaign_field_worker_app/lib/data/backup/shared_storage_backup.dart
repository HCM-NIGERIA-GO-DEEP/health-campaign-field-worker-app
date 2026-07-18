import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:digit_ui_components/utils/app_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shared plumbing for backup files kept in public shared storage (the
/// device `Documents` folder) so they survive the user clearing the app's
/// storage. Everything inside the app sandbox — SharedPreferences, the
/// Drift/Isar databases and `Android/data/<pkg>` — is wiped by
/// "Clear storage", so this is the only local location that outlives it.
class SharedStorageBackup {
  SharedStorageBackup._internal();

  static final SharedStorageBackup _instance =
      SharedStorageBackup._internal();

  static SharedStorageBackup get instance => _instance;

  static const String _folderName = 'HCMBackup';

  bool _requestedThisSession = false;

  Future<bool> _hasStorageAccess() async {
    if (!Platform.isAndroid) return false;

    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final permission = sdkInt >= 30
        ? Permission.manageExternalStorage
        : Permission.storage;

    if (await permission.isGranted) return true;
    if (_requestedThisSession) return false;

    _requestedThisSession = true;
    final status = await permission.request();
    return status.isGranted;
  }

  Future<File?> _fileFor(String fileName) async {
    final appDir = await getExternalStorageDirectory();
    if (appDir == null) return null;

    // `getExternalStorageDirectory` points inside `Android/data/<pkg>`, which
    // is wiped with the app's storage. Climb up to the shared storage root.
    final root = appDir.path.split('/Android/').first;

    final dir = Directory('$root/Documents/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return File('${dir.path}/$fileName');
  }

  /// Reads the JSON object stored in [fileName]. Returns an empty map when
  /// the file is missing, unreadable, corrupted or access is denied.
  Future<Map<String, dynamic>> readJson(String fileName) async {
    try {
      if (!await _hasStorageAccess()) return <String, dynamic>{};

      final file = await _fileFor(fileName);
      if (file == null || !await file.exists()) return <String, dynamic>{};

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (error) {
      AppLogger.instance.error(
        title: runtimeType.toString(),
        message: 'Failed to read backup $fileName: $error',
      );
    }

    return <String, dynamic>{};
  }

  /// Writes [data] as JSON to [fileName]. Silently skips when shared storage
  /// access is unavailable.
  Future<void> writeJson(String fileName, Map<String, dynamic> data) async {
    try {
      if (!await _hasStorageAccess()) return;

      final file = await _fileFor(fileName);
      if (file == null) return;

      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (error) {
      AppLogger.instance.error(
        title: runtimeType.toString(),
        message: 'Failed to write backup $fileName: $error',
      );
    }
  }
}
