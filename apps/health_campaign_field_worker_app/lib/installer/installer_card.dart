import 'package:digit_installer/digit_installer.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/digit_tag.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';

import 'app_update_controller.dart';

/// Home-screen card that only appears while there's an update to act on —
/// available, downloading, ready to install, or a failed download/install.
/// Checks run in [AppUpdateController]; see there for when.
class InstallerCard extends StatefulWidget {
  const InstallerCard({super.key});

  @override
  State<InstallerCard> createState() => _InstallerCardState();
}

class _InstallerCardState extends State<InstallerCard> {
  final _controller = AppUpdateController.instance;

  @override
  void initState() {
    super.initState();
    // The "when the home screen opens" check; sync ticks cover the rest.
    _controller.checkForUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final info = _controller.packageInfo;
        final installer = _controller.installer;
        if (info == null || installer == null || !_controller.isVisible) {
          return const SizedBox.shrink();
        }
        final state = _controller.state;
        final checkingExistingDownload = _controller.checkingExistingDownload;

        return DigitCard(
          margin: const EdgeInsets.all(spacer2),
          children: [
            _Header(currentVersion: info.version),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, if (current != null) current],
                ),
                child: _StateView(
                  key: ValueKey((state.runtimeType, checkingExistingDownload)),
                  state: state,
                  installer: installer,
                  manifest: _controller.manifest,
                  checkingExistingDownload: checkingExistingDownload,
                  onRetry: _controller.retry,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Runs an update check from the side menu and reports the result as a
/// toast, since the card itself stays hidden unless there's an update.
Future<void> checkForUpdateFromMenu(BuildContext context) async {
  final controller = AppUpdateController.instance;
  final state = await controller.checkForUpdate();
  if (!context.mounted) return;

  final (message, type) = switch (state) {
    UpdateUpToDate(:final currentVersion) => (
        "You're on the latest version ($currentVersion)",
        ToastType.success,
      ),
    _ when controller.isVisible => (
        'Version ${controller.manifest?.version ?? ''} is available. '
            'Open Home to update.',
        ToastType.info,
      ),
    _ => (
        "Couldn't check for updates. Check your internet connection and "
            'try again.',
        ToastType.error,
      ),
  };
  Toast.showToast(context, message: message, type: type);
}

class _Header extends StatelessWidget {
  const _Header({required this.currentVersion});

  final String currentVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(spacer2),
          decoration: BoxDecoration(
            color: theme.colorTheme.primary.primaryBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.system_update_alt,
            color: theme.colorTheme.primary.primary1,
            size: spacer6,
          ),
        ),
        const SizedBox(width: spacer3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App update',
                style: textTheme.headingS
                    .copyWith(color: theme.colorTheme.text.primary),
              ),
              const SizedBox(height: spacer1),
              Text(
                'Current version $currentVersion',
                style: textTheme.bodyS
                    .copyWith(color: theme.colorTheme.text.secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    super.key,
    required this.state,
    required this.installer,
    required this.manifest,
    required this.checkingExistingDownload,
    required this.onRetry,
  });

  final UpdateState state;
  final DigitInstaller installer;
  final UpdateManifest? manifest;

  /// See [AppUpdateController.checkingExistingDownload].
  final bool checkingExistingDownload;

  final VoidCallback onRetry;

  /// "Version 1.2.3" when the in-flight manifest is known, else a generic
  /// fallback — keeps every in-progress label naming what's being fetched.
  String _versionLabel(String fallback) {
    final version = manifest?.version;
    return version == null ? fallback : 'version $version';
  }

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      // The card is hidden in these — see AppUpdateController.isVisible.
      UpdateIdle() ||
      UpdateChecking() ||
      UpdateUpToDate() ||
      UpdateInstalled() =>
        const SizedBox.shrink(),
      UpdateAvailable(:final manifest) => checkingExistingDownload
          ? const _ProgressView(label: 'Checking for a previous download…')
          : _AvailableView(manifest: manifest, onDownload: installer.download),
      UpdateInitializing() => const _ProgressView(label: 'Preparing download…'),
      UpdateDownloading(:final progress) => _ProgressView(
          label: 'Downloading ${_versionLabel('update')}',
          fraction: progress.fraction,
          detail: _transferDetail(
            progress.bytesReceived,
            progress.totalBytes,
            progress.bytesPerSecond,
          ),
        ),
      UpdatePaused(:final progress) => _Section(children: [
          _ProgressView(
            label: 'Download paused',
            fraction: progress.fraction,
            detail: _transferDetail(
              progress.bytesReceived,
              progress.totalBytes,
            ),
          ),
          _ActionButton(
            label: 'Resume download',
            icon: Icons.play_arrow,
            onPressed: installer.download,
          ),
        ]),
      UpdateVerifying() => const _ProgressView(label: 'Verifying download…'),
      UpdateVerified(:final manifest) => _Section(children: [
          _BodyText(
            'Version ${manifest.version} is downloaded and verified. '
            'The app will close and reopen to finish installing.',
          ),
          _ActionButton(
            label: 'Install now',
            icon: Icons.install_mobile,
            onPressed: installer.install,
          ),
        ]),
      UpdateInstalling(:final fraction) => _ProgressView(
          label: 'Installing ${_versionLabel('update')}',
          fraction: fraction,
        ),
      UpdateFailed(:final reason) => _FailureView(
          reason: reason,
          installer: installer,
          onRetry: onRetry,
        ),
    };
  }
}

/// Shown for [UpdateAvailable]: what's new, how big it is, and whether it's
/// required — enough for a field worker on metered data to decide now.
class _AvailableView extends StatelessWidget {
  const _AvailableView({required this.manifest, required this.onDownload});

  final UpdateManifest manifest;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    final size = manifest.size;
    final releaseNotes = manifest.releaseNotes?.trim() ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Version ${manifest.version} is available',
                // headingXS is 12px on mobile — smaller than the body copy.
                style: textTheme.bodyS.copyWith(
                  color: theme.colorTheme.text.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (manifest.mandatory) ...[
              const SizedBox(width: spacer2),
              const Tag(label: 'Required', type: TagType.warning),
            ],
          ],
        ),
        if (size != null && size > 0) ...[
          const SizedBox(height: spacer1),
          _BodyText('Download size ${_formatBytes(size)}'),
        ],
        if (releaseNotes.isNotEmpty) ...[
          const SizedBox(height: spacer3),
          _ReleaseNotes(releaseNotes),
        ],
        const SizedBox(height: spacer4),
        _ActionButton(
          label: 'Download update',
          icon: Icons.download,
          onPressed: onDownload,
        ),
      ],
    );
  }
}

/// Release notes clipped to [_collapsedLines], with a "Show more" toggle only
/// when they actually run longer. The card's [AnimatedSize] animates the
/// height change.
class _ReleaseNotes extends StatefulWidget {
  const _ReleaseNotes(this.text);

  final String text;

  static const _collapsedLines = 4;

  @override
  State<_ReleaseNotes> createState() => _ReleaseNotesState();
}

class _ReleaseNotesState extends State<_ReleaseNotes> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme
        .digitTextTheme(context)
        .bodyS
        .copyWith(color: theme.colorTheme.text.primary);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _ReleaseNotes._collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : _ReleaseNotes._collapsedLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: style,
            ),
            if (overflows)
              DigitButton(
                label: _expanded ? 'Show less' : 'Show more',
                suffixIcon: _expanded ? Icons.expand_less : Icons.expand_more,
                type: DigitButtonType.link,
                size: DigitButtonSize.medium,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
          ],
        );
      },
    );
  }
}

/// Label + bar for every busy state. A null [fraction] renders an
/// indeterminate bar, so checking → preparing → downloading → verifying keep
/// the bar in the same place instead of swapping between spinner and bar.
class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.label, this.fraction, this.detail});

  final String label;
  final double? fraction;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    final fraction = this.fraction;
    final detail = this.detail;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyS
                    .copyWith(color: theme.colorTheme.text.primary),
              ),
            ),
            if (fraction != null)
              Text(
                _formatPercent(fraction),
                style: textTheme.label
                    .copyWith(color: theme.colorTheme.primary.primary1),
              ),
          ],
        ),
        const SizedBox(height: spacer2),
        LinearProgressIndicator(
          value: fraction,
          semanticsLabel: label,
          backgroundColor: theme.colorTheme.generic.background,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorTheme.primary.primary1,
          ),
          minHeight: 7.0,
          borderRadius: BorderRadius.circular(spacer1),
        ),
        if (detail != null) ...[
          const SizedBox(height: spacer2),
          _BodyText(detail),
        ],
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.reason,
    required this.installer,
    required this.onRetry,
  });

  final UpdateFailure reason;
  final DigitInstaller installer;
  final VoidCallback onRetry;

  String _title(UpdateFailure reason) => switch (reason) {
        UserCancelled() => 'Update cancelled',
        InstallUnknownAppsNotPermitted() => 'Permission needed',
        _ => 'Update failed',
      };

  /// Human-readable message per failure kind — pattern-matched exhaustively
  /// so a new [UpdateFailure] variant fails to compile here instead of
  /// silently falling back to a raw `toString()`.
  String _message(UpdateFailure reason) => switch (reason) {
        NetworkFailure(:final message) =>
          "Couldn't reach the update server. Check your internet connection "
              'and try again.\n($message)',
        ManifestParseFailure() =>
          'The update information from the server was malformed.',
        ChecksumMismatch() =>
          'The downloaded file failed checksum verification.',
        SignatureMismatch() =>
          "The downloaded app's signing certificate didn't match.",
        CertificatePinningFailure(:final host) =>
          'The secure connection to $host could not be verified.',
        UserCancelled() => 'The update was cancelled before it finished.',
        InstallUnknownAppsNotPermitted() =>
          'Allow this app to install updates: tap Open settings, turn on '
              '"Allow from this source", then come back and tap Try again.',
        UnsupportedPlatform(:final operation, :final platform) =>
          "$operation isn't supported on $platform.",
        InstallerError(:final message) => 'Installation failed: $message',
        DownloadIncomplete(:final bytesReceived, :final totalBytes) =>
          'The download stopped early (${_formatBytes(bytesReceived)} of '
              '${_formatBytes(totalBytes)}).',
        UnknownFailure(:final error) => 'Unexpected error: $error',
      };

  @override
  Widget build(BuildContext context) {
    return _Section(children: [
      InfoCard(
        type: reason is UserCancelled ? InfoType.warning : InfoType.error,
        title: _title(reason),
        description: _message(reason),
        // Its default sentence-casing lowercases hostnames, versions and
        // native error text.
        capitalizedLetter: false,
      ),
      if (reason is InstallUnknownAppsNotPermitted)
        _ActionButton(
          label: 'Open settings',
          icon: Icons.settings,
          type: DigitButtonType.secondary,
          onPressed: installer.openInstallUnknownAppsSettings,
        ),
      _ActionButton(
        label: 'Try again',
        icon: Icons.refresh,
        onPressed: onRetry,
      ),
    ]);
  }
}

/// Stacks a state's blocks with consistent spacing between them.
class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: spacer4),
          children[i],
        ],
      ],
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme
          .digitTextTheme(context)
          .bodyS
          .copyWith(color: theme.colorTheme.text.secondary),
    );
  }
}

/// Full-width, large (48dp) so the card's one action is an easy tap target.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.type = DigitButtonType.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final DigitButtonType type;

  @override
  Widget build(BuildContext context) {
    return DigitButton(
      label: label,
      prefixIcon: icon,
      type: type,
      size: DigitButtonSize.large,
      mainAxisSize: MainAxisSize.max,
      onPressed: onPressed,
    );
  }
}

/// "12.4 MB of 85.3 MB" (+ " · 1.2 MB/s" while transferring). Falls back to
/// just the received amount when the server didn't report a total. Takes
/// the fields rather than `DownloadProgress`, which `digit_installer`
/// doesn't re-export.
String _transferDetail(
  int bytesReceived,
  int totalBytes, [
  double bytesPerSecond = 0,
]) {
  final received = _formatBytes(bytesReceived);
  final amount =
      totalBytes > 0 ? '$received of ${_formatBytes(totalBytes)}' : received;
  return bytesPerSecond > 0
      ? '$amount · ${_formatBytes(bytesPerSecond)}/s'
      : amount;
}

String _formatBytes(num bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

String _formatPercent(double fraction) =>
    '${(fraction.clamp(0, 1) * 100).toStringAsFixed(0)}%';
