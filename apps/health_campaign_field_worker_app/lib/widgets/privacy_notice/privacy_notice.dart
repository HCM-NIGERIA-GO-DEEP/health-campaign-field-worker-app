import 'dart:convert';

import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../blocs/localization/app_localization.dart';
import '../../blocs/localization/localization.dart';
import '../../sampleJsonConfigs/privacy_notice.dart';

/// Loads the privacy-notice flow from the cached app-config schemas
/// (`PRIVACYNOTICE`), falling back to the bundled [privacy_notice_config].
/// Returns `null` when the notice is disabled or no flow is configured.
Future<Map<String, dynamic>?> loadPrivacyNoticeFlow() async {
  final prefs = await SharedPreferences.getInstance();
  final schemaJsonRaw = prefs.getString('app_config_schemas');

  try {
    if (schemaJsonRaw != null) {
      final allSchemas = json.decode(schemaJsonRaw) as Map<String, dynamic>;
      final data = allSchemas['PRIVACYNOTICE'];
      final schemaData = data?['data'];

      if (schemaData?['disabled'] == true) {
        return null;
      }

      final flows = (schemaData?['flows'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];

      if (flows.isNotEmpty) {
        return flows.first;
      }
    }
  } catch (_) {}

  if (privacy_notice_config['disabled'] == true) {
    return null;
  }

  final fallbackFlows = privacy_notice_config['flows'] as List<dynamic>?;
  if (fallbackFlows != null && fallbackFlows.isNotEmpty) {
    return Map<String, dynamic>.from(fallbackFlows.first as Map);
  }

  return null;
}

/// Shows the full-screen privacy notice as a blocking dialog. Returns `true`
/// once the user taps "Proceed", and `false` if the notice is disabled /
/// unconfigured (nothing shown).
Future<bool> showPrivacyNotice(BuildContext context) async {
  final privacyFlow = await loadPrivacyNoticeFlow();

  if (!context.mounted || privacyFlow == null) return false;

  final proceeded = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: AppLocalizations.of(context)
        .translate(privacyFlow["heading"] ?? "PRIVACY_POLICY"),
    pageBuilder: (dialogContext, _, __) {
      return PrivacyNoticeFullscreenPopup(
        flow: privacyFlow,
        onProceed: () async {
          Navigator.of(dialogContext, rootNavigator: true).pop(true);
        },
      );
    },
  );

  return proceeded ?? false;
}

class PrivacyNoticeFullscreenPopup extends StatefulWidget {
  final Map<String, dynamic> flow;
  final Future<void> Function() onProceed;

  const PrivacyNoticeFullscreenPopup({
    super.key,
    required this.flow,
    required this.onProceed,
  });

  @override
  State<PrivacyNoticeFullscreenPopup> createState() =>
      _PrivacyNoticeFullscreenPopupState();
}

class _PrivacyNoticeFullscreenPopupState
    extends State<PrivacyNoticeFullscreenPopup> {
  final ScrollController _scrollController = ScrollController();
  bool _hasReachedEnd = false;

  Future<void> _openExternalUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildTextWithOptionalLink({
    required String value,
    required TextStyle style,
  }) {
    final urlRegex = RegExp(r'https?:\/\/[^\s]+');
    final match = urlRegex.firstMatch(value);

    if (match == null) {
      return Text(value, style: style);
    }

    final before = value.substring(0, match.start);
    final url = value.substring(match.start, match.end);
    final after = value.substring(match.end);

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => _openExternalUrl(url),
              child: Text(
                url,
                style: style.copyWith(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) {
        setState(() {
          _hasReachedEnd = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _hasReachedEnd) return;
    final position = _scrollController.position;
    if (position.pixels >= (position.maxScrollExtent - 16)) {
      setState(() {
        _hasReachedEnd = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationBloc, LocalizationState>(
      buildWhen: (previous, current) {
        // Rebuild only after localization load settles to avoid showing keys.
        if (previous.loading != current.loading) {
          return current.loading == false;
        }

        return previous.index != current.index && current.loading == false;
      },
      builder: (context, _) {
        final theme = Theme.of(context);
        final textTheme = theme.digitTextTheme(context);
        final bodyItems = widget.flow['body'] as List<dynamic>? ?? const [];

        return PopScope(
          canPop: false,
          child: Material(
            color: theme.colorTheme.generic.background,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(spacer2),
                      child: DigitCard(
                        margin: EdgeInsets.zero,
                        children: [
                          Text(
                            AppLocalizations.of(context).translate(
                                widget.flow['heading'] as String? ??
                                    'PRIVACY_NOTICE'),
                            style: textTheme.headingXl.copyWith(
                              color: theme.colorTheme.primary.primary2,
                            ),
                          ),
                          ...bodyItems.map((item) {
                            final content = item is Map
                                ? Map<String, dynamic>.from(item)
                                : <String, dynamic>{};
                            final format =
                                content['format'] as String? ?? 'text';
                            final value = content['value'] as String? ?? '';
                            final isBold = content['bold'] as bool? ?? false;
                            final isCompact =
                                content['compact'] as bool? ?? false;

                            if (format == 'heading') {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 0),
                                child: Text(
                                  value,
                                  style: isCompact
                                      ? textTheme.bodyS.copyWith(
                                          color:
                                              theme.colorTheme.primary.primary2,
                                          fontWeight: FontWeight.w700,
                                          height: 1.0,
                                        )
                                      : textTheme.headingM.copyWith(
                                          color:
                                              theme.colorTheme.primary.primary2,
                                          height: 1.0,
                                        ),
                                ),
                              );
                            }

                            if (format == 'bullet') {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: textTheme.bodyS.copyWith(
                                        color:
                                            theme.colorTheme.primary.primary2,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        value,
                                        style: textTheme.bodyS.copyWith(
                                          color:
                                              theme.colorTheme.primary.primary2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: spacer1),
                              child: _buildTextWithOptionalLink(
                                value: value,
                                style: textTheme.bodyS.copyWith(
                                  color: theme.colorTheme.primary.primary2,
                                  fontWeight: isBold ? FontWeight.w700 : null,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  DigitCard(
                    margin: const EdgeInsets.only(top: spacer2),
                    children: [
                      DigitButton(
                        mainAxisSize: MainAxisSize.max,
                        isDisabled: !_hasReachedEnd,
                        label: AppLocalizations.of(context).translate(
                          widget.flow['proceedLabel'] as String? ?? 'PROCEED',
                        ),
                        type: DigitButtonType.primary,
                        size: DigitButtonSize.large,
                        onPressed: () {
                          widget.onProceed();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
