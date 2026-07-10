import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/ComponentTheme/button_theme.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:attendance_management/blocs/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../utils/i18_key_constants.dart' as i18;

/// Shows a signature-capture popup and returns the captured signature encoded
/// as a base64 PNG string. Returns `null` if the user dismisses the popup
/// without confirming a signature.
///
/// This is a self-contained re-implementation of the flow-builder signature
/// widget so the native attendance flow (which does not depend on
/// digit_flow_builder) can capture a worker's signature when marking present.
Future<String?> showSignatureCaptureDialog(
  BuildContext context, {
  String? existingSignature,
}) async {
  final localizations = AttendanceLocalization.of(context);

  final result = await showCustomPopup(
    context: context,
    barrierDismissible: true,
    builder: (popupContext) {
      return Popup(
        title: localizations.translate(i18.attendance.captureSignatureLabel),
        titleIcon: Icon(
          Icons.check_circle,
          color: DigitTheme.instance.colorScheme.primary,
        ),
        onCrossTap: () => Navigator.of(popupContext, rootNavigator: true).pop(),
        additionalWidgets: [
          _SignatureCapture(
            clearSignatureLabel:
                localizations.translate(i18.attendance.clearSignatureLabel),
            saveSignatureLabel:
                localizations.translate(i18.attendance.confirmSignatureLabel),
            signatureRequiredLabel:
                localizations.translate(i18.attendance.signatureRequiredLabel),
            existingSignature: existingSignature,
            onSave: (signatureBase64) {
              Navigator.of(popupContext, rootNavigator: true)
                  .pop(signatureBase64);
            },
          ),
        ],
        inlineActions: true,
      );
    },
  );

  return result is String ? result : null;
}

/// Shows a signature-compare popup with the previously captured reference
/// signature alongside the just-captured one, and a Match / Not Matched choice.
///
/// Returns `true` if the user taps Match, `false` for Not Matched, and `null`
/// if the popup is dismissed without a choice.
Future<bool?> showSignatureCompareDialog(
  BuildContext context, {
  String? referenceSignature,
  required String currentSignature,
}) async {
  final localizations = AttendanceLocalization.of(context);

  final result = await showCustomPopup(
    context: context,
    barrierDismissible: true,
    builder: (popupContext) {
      final theme = Theme.of(popupContext);
      return Popup(
        title: localizations.translate(i18.attendance.compareSignatureLabel),
        titleIcon: Icon(
          Icons.check_circle,
          color: DigitTheme.instance.colorScheme.primary,
        ),
        onCrossTap: () => Navigator.of(popupContext, rootNavigator: true).pop(),
        additionalWidgets: [
          _SignatureCompare(
            referenceSignature: referenceSignature,
            currentSignature: currentSignature,
            referenceLabel:
                localizations.translate(i18.attendance.referenceSignatureLabel),
            actualLabel:
                localizations.translate(i18.attendance.actualSignatureLabel),
          ),
          const SizedBox(height: spacer2),
          // Match / no-match actions: full-width row, Matches (green) on the
          // left, Doesn't match (red) on the right. Filled + rounded.
          Row(
            children: [
              Expanded(
                child: DigitButton(
                  label: 'Matches',
                  prefixIcon: Icons.check,
                  mainAxisSize: MainAxisSize.max,
                  type: DigitButtonType.primary,
                  size: DigitButtonSize.small,
                  textColor: theme.colorTheme.paper.primary,
                  iconColor: theme.colorTheme.paper.primary,
                  digitButtonThemeData: DigitButtonThemeData(
                    DigitButtonColor: theme.colorTheme.alert.success,
                    primaryDigitButtonColor: theme.colorTheme.alert.success,
                    radius: BorderRadius.circular(8),
                    largeRadius: BorderRadius.circular(8),
                    smallMediumRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                  ),
                  onPressed: () =>
                      Navigator.of(popupContext, rootNavigator: true)
                          .pop(true),
                ),
              ),
              const SizedBox(width: spacer2),
              Expanded(
                child: DigitButton(
                  label: "Doesn't match",
                  prefixIcon: Icons.close,
                  mainAxisSize: MainAxisSize.max,
                  type: DigitButtonType.primary,
                  size: DigitButtonSize.small,
                  textColor: theme.colorTheme.paper.primary,
                  iconColor: theme.colorTheme.paper.primary,
                  digitButtonThemeData: DigitButtonThemeData(
                    DigitButtonColor: theme.colorTheme.alert.error,
                    primaryDigitButtonColor: theme.colorTheme.alert.error,
                    radius: BorderRadius.circular(8),
                    largeRadius: BorderRadius.circular(8),
                    smallMediumRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                  ),
                  onPressed: () =>
                      Navigator.of(popupContext, rootNavigator: true)
                          .pop(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: spacer3),
        ],
      );
    },
  );

  return result is bool ? result : null;
}

/// Shows the reference signature and the just-captured signature stacked, each
/// labelled, for visual comparison.
class _SignatureCompare extends StatelessWidget {
  final String? referenceSignature;
  final String currentSignature;
  final String referenceLabel;
  final String actualLabel;

  const _SignatureCompare({
    required this.referenceSignature,
    required this.currentSignature,
    required this.referenceLabel,
    required this.actualLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Size each tile to its signature image (no AspectRatio/Expanded) so the
    // popup stays compact and there's no large empty gap below the pad.
    final tileHeight = referenceSignature == null ? 230.0 : 130.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: spacer2),
        if (referenceSignature != null) ...[
          SizedBox(
            height: tileHeight,
            child:
                _signatureTile(context, referenceSignature!, referenceLabel),
          ),
          const SizedBox(height: spacer3),
        ],
        SizedBox(
          height: tileHeight,
          child: _signatureTile(context, currentSignature, actualLabel),
        ),
      ],
    );
  }

  Widget _signatureTile(BuildContext context, String base64Data, String label) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            width: Base.defaultBorderWidth,
            color: theme.colorTheme.generic.divider,
          ),
          borderRadius: BorderRadius.circular(radius4),
          color: theme.colorTheme.paper.secondary,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Image.memory(
                base64Decode(base64Data),
                color: null,
                colorBlendMode: null,
                height: referenceSignature == null ? 200 : 90,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
            Positioned(
              bottom: 0,
              width: MediaQuery.of(context).size.width,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(50),
                  border: Border.all(
                    width: Base.defaultBorderWidth,
                    color: Colors.blueAccent,
                  ),
                ),
                child: Center(child: Text(label)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The signature pad wrapped with Clear and Confirm actions.
class _SignatureCapture extends StatefulWidget {
  final String clearSignatureLabel;
  final String saveSignatureLabel;
  final String signatureRequiredLabel;
  final String? existingSignature;
  final ValueChanged<String> onSave;

  const _SignatureCapture({
    required this.clearSignatureLabel,
    required this.saveSignatureLabel,
    required this.signatureRequiredLabel,
    required this.existingSignature,
    required this.onSave,
  });

  @override
  State<_SignatureCapture> createState() => _SignatureCaptureState();
}

class _SignatureCaptureState extends State<_SignatureCapture> {
  final SignatureController _signatureController = SignatureController();
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isSaving = false;

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: DigitCard(
            cardType: CardType.secondary,
            children: [
              AspectRatio(
                aspectRatio: 2,
                child: SignaturePad(
                  controller: _signatureController,
                  repaintBoundaryKey: _repaintBoundaryKey,
                  strokeWidth: 3.0,
                  strokeColor: Colors.black,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: spacer4),
        Row(
          children: [
            // Clear Button
            Expanded(
              child: DigitButton(
                label: widget.clearSignatureLabel,
                type: DigitButtonType.secondary,
                size: DigitButtonSize.small,
                onPressed: () {
                  _signatureController.clear();
                },
                digitButtonThemeData: DigitButtonThemeData(
                  primaryDigitButtonColor:
                      DigitButtonThemeData.defaultTheme(context)
                          .primaryDigitButtonColor,
                  DigitButtonColor: DigitButtonThemeData.defaultTheme(context)
                      .DigitButtonColor,
                  disabledColor:
                      DigitButtonThemeData.defaultTheme(context).disabledColor,
                  radius: BorderRadius.circular(spacer2),
                  largeRadius: BorderRadius.circular(spacer2),
                  smallMediumRadius: BorderRadius.circular(spacer2),
                  padding: const EdgeInsets.all(spacer2),
                ),
              ),
            ),
            const SizedBox(width: spacer3),
            // Save Button
            Expanded(
              child: DigitButton(
                label: widget.saveSignatureLabel,
                type: DigitButtonType.primary,
                size: DigitButtonSize.small,
                isDisabled: _isSaving,
                onPressed: _isSaving ? () {} : _saveSignature,
                digitButtonThemeData: DigitButtonThemeData(
                  primaryDigitButtonColor:
                      DigitButtonThemeData.defaultTheme(context)
                          .primaryDigitButtonColor,
                  DigitButtonColor: DigitButtonThemeData.defaultTheme(context)
                      .DigitButtonColor,
                  disabledColor:
                      DigitButtonThemeData.defaultTheme(context).disabledColor,
                  radius: BorderRadius.circular(spacer2),
                  largeRadius: BorderRadius.circular(spacer2),
                  smallMediumRadius: BorderRadius.circular(spacer2),
                  padding: const EdgeInsets.all(spacer2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveSignature() async {
    if (_signatureController.isEmpty) {
      Toast.showToast(
        context,
        message: widget.signatureRequiredLabel,
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final signatureBytes =
          await SignaturePad.captureSignature(_repaintBoundaryKey);
      if (signatureBytes != null) {
        widget.onSave(base64Encode(signatureBytes));
      } else if (mounted) {
        setState(() => _isSaving = false);
      }
    } catch (e) {
      debugPrint('Error saving signature: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

/// A point in the signature with normalized coordinates (0-1).
class SigPoint {
  final double x;
  final double y;

  const SigPoint(this.x, this.y);
}

/// Controller for managing signature strokes.
class SignatureController extends ChangeNotifier {
  final List<List<SigPoint>> _strokes = [];
  List<SigPoint> _currentStroke = [];

  bool get isEmpty => _strokes.isEmpty && _currentStroke.isEmpty;

  void startStroke() => _currentStroke = [];

  void addPoint(SigPoint point) {
    _currentStroke.add(point);
    notifyListeners();
  }

  void endStroke() {
    if (_currentStroke.isNotEmpty) {
      _strokes.add(List.from(_currentStroke));
      _currentStroke = [];
      notifyListeners();
    }
  }

  void clear() {
    _strokes.clear();
    _currentStroke.clear();
    notifyListeners();
  }

  List<List<SigPoint>> getAllStrokes() {
    if (_currentStroke.isNotEmpty) {
      return [..._strokes, _currentStroke];
    }
    return _strokes;
  }
}

/// A signature pad widget that allows users to draw signatures.
class SignaturePad extends StatelessWidget {
  final SignatureController controller;
  final Color strokeColor;
  final double strokeWidth;
  final Color backgroundColor;
  final GlobalKey? repaintBoundaryKey;

  const SignaturePad({
    super.key,
    required this.controller,
    this.strokeColor = Colors.black,
    this.strokeWidth = 3.0,
    this.backgroundColor = Colors.transparent,
    this.repaintBoundaryKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => controller.startStroke(),
                onPanUpdate: (details) {
                  final local = details.localPosition;
                  controller.addPoint(
                    SigPoint(local.dx / width, local.dy / height),
                  );
                },
                onPanEnd: (_) => controller.endStroke(),
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, __) => CustomPaint(
                    painter: _SignaturePainter(
                      controller.getAllStrokes(),
                      strokeColor: strokeColor,
                      strokeWidth: strokeWidth,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Captures the signature as PNG bytes.
  static Future<Uint8List?> captureSignature(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing signature: $e');
      return null;
    }
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<SigPoint>> strokes;
  final Color strokeColor;
  final double strokeWidth;

  _SignaturePainter(
    this.strokes, {
    this.strokeColor = Colors.black,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      if (stroke.length == 1) {
        final point = stroke.first;
        canvas.drawCircle(
          Offset(point.x * size.width, point.y * size.height),
          strokeWidth / 2,
          paint,
        );
        continue;
      }

      final path = Path();
      final first = stroke.first;
      path.moveTo(first.x * size.width, first.y * size.height);
      for (int i = 1; i < stroke.length; i++) {
        final point = stroke[i];
        path.lineTo(point.x * size.width, point.y * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
