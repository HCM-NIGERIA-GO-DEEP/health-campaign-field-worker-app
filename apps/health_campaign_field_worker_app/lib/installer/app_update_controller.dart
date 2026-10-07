import 'dart:io';

import 'package:digit_installer/digit_installer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'installer_config.dart';

/// Owns the app's single [DigitInstaller] and decides when to check for an
/// update: when the home screen opens, on every auto-sync tick of the
/// background service, and on demand from the side menu.
///
/// App-lifetime rather than owned by `InstallerCard`, so a download in
/// progress survives the home page being rebuilt or replaced, and the side
/// menu can trigger a check without the card being on screen.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController._();

  static final instance = AppUpdateController._();

  Future<void>? _starting;
  PackageInfo? _packageInfo;
  DigitInstaller? _installer;
  Future<void>? _inFlightCheck;

  UpdateState _state = const UpdateIdle();

  /// Most recent manifest seen. [UpdateDownloading], [UpdatePaused] and
  /// friends don't carry it, but the card keeps naming the version in flight.
  UpdateManifest? _manifest;

  /// True while checking whether [UpdateAvailable]'s manifest is already
  /// downloaded on disk — see [_skipDownloadIfAlreadyPresent].
  bool _checkingExistingDownload = false;

  /// Whether the last [UpdateFailed] came out of [DigitInstaller.install]
  /// (the APK is still on disk and verified), so "Try again" can go straight
  /// back to installing instead of downloading again.
  bool _failedDuringInstall = false;

  /// Whether the last [UpdateFailed] came out of a download or install the
  /// user started. Those are shown so they can retry; a failed background
  /// check (e.g. offline) is not, and the next sync tick simply tries again.
  bool _failedWhileUpdating = false;

  PackageInfo? get packageInfo => _packageInfo;
  DigitInstaller? get installer => _installer;
  UpdateState get state => _state;
  UpdateManifest? get manifest => _manifest;
  bool get checkingExistingDownload => _checkingExistingDownload;

  /// The card is only shown while there's an update to act on.
  bool get isVisible => switch (_state) {
        UpdateIdle() ||
        UpdateChecking() ||
        UpdateUpToDate() ||
        UpdateInstalled() =>
          false,
        UpdateFailed() => _failedWhileUpdating,
        _ => true,
      };

  /// Sets up the installer and subscribes to the auto-sync tick. Idempotent.
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    // Nothing to check against — the card stays hidden.
    if (!isGithubReleaseHostConfigured) return;

    final info = await PackageInfo.fromPlatform();
    final installer = DigitInstaller(
      DigitInstallerConfig(
        manifestUrl: githubManifestUrl,
        headersBuilder: githubToken.isEmpty
            ? null
            : () async => {'Authorization': 'Bearer $githubToken'},
        // The install always kills this app's process — see
        // DigitInstallerConfig.reopenAfterInstall — so relaunch afterward
        // instead of leaving the user on the home screen.
        reopenAfterInstall: true,
      ),
    );
    installer.updates.listen(_onState);
    _packageInfo = info;
    _installer = installer;

    // The background service sends this with enablesManualSync: false once
    // at the start of every auto-sync tick (see background_service.dart).
    FlutterBackgroundService().on('serviceRunning').listen((event) {
      if (event?['enablesManualSync'] == false) checkForUpdate();
    });
    notifyListeners();
  }

  /// Fetches the manifest unless an update is already found or in flight,
  /// and returns the resulting state. Concurrent calls share one request.
  Future<UpdateState> checkForUpdate() async {
    await start();
    final installer = _installer;
    final info = _packageInfo;
    if (installer == null || info == null) return _state;

    final inFlight = _inFlightCheck;
    if (inFlight != null) {
      await inFlight;
      return _state;
    }
    // Re-checking would reset an available or downloading update.
    if (isVisible) return _state;

    final check = installer.checkForUpdate(
      currentVersionCode: int.tryParse(info.buildNumber) ?? 1,
      currentVersion: info.version,
    );
    _inFlightCheck = check;
    try {
      await check;
    } finally {
      _inFlightCheck = null;
    }
    return _state;
  }

  /// "Try again" after a failed download or install.
  void retry() {
    final installer = _installer;
    if (installer == null) return;
    _failedDuringInstall ? installer.install() : installer.download();
  }

  void _onState(UpdateState state) {
    if (state is UpdateFailed) {
      // A retry can fail before emitting a progress state of its own, so
      // keep the previous failure's classification in that case.
      if (_state is! UpdateFailed) {
        _failedDuringInstall =
            _state is UpdateVerified || _state is UpdateInstalling;
        _failedWhileUpdating = switch (_state) {
          UpdateInitializing() ||
          UpdateDownloading() ||
          UpdatePaused() ||
          UpdateVerifying() ||
          UpdateVerified() ||
          UpdateInstalling() =>
            true,
          _ => false,
        };
      }
    }
    if (state is UpdateAvailable) _manifest = state.manifest;
    if (state is UpdateVerified) _manifest = state.manifest;
    _state = state;
    notifyListeners();

    if (state is UpdateInstalled) _deleteDownloadedApk();
    if (state is UpdateAvailable) {
      _skipDownloadIfAlreadyPresent(state.manifest);
    }
  }

  /// `digit_installer` never deletes the downloaded APK on its own (see
  /// [DigitInstaller.lastFilePath]) — a multi-hundred-MB file would otherwise
  /// sit in app storage indefinitely after every successful update.
  Future<void> _deleteDownloadedApk() async {
    final path = _installer?.lastFilePath;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Failed to delete downloaded APK at $path: $e');
    }
  }

  /// A previous [DigitInstaller.download] may have already fetched and
  /// verified this exact manifest's file without a follow-up [install] —
  /// e.g. the app was closed before the user tapped Install. When that's
  /// the case, skip showing a "Download" button entirely: kick off
  /// [DigitInstaller.download] right away (it detects the match and skips
  /// the network transfer) so the UI moves straight to "Install" instead.
  Future<void> _skipDownloadIfAlreadyPresent(UpdateManifest manifest) async {
    final installer = _installer;
    if (installer == null) return;
    _checkingExistingDownload = true;
    notifyListeners();
    final alreadyDownloaded = await installer.isDownloaded(manifest);
    _checkingExistingDownload = false;
    notifyListeners();
    if (alreadyDownloaded) installer.download();
  }
}
