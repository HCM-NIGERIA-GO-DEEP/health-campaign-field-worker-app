// part 'auth.freezed.dart' need to be added to auto generate the files for freezed model
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gs1_barcode_parser/gs1_barcode_parser.dart';

part 'scanner.freezed.dart';

typedef DigitScannerEmitter = Emitter<DigitScannerState>;

class DigitScannerBloc extends Bloc<DigitScannerEvent, DigitScannerState> {
  DigitScannerBloc(
    super.initialState,
  ) {
    on<DigitScannerScanEvent>(_handleScanner);
    on<DigitScannerClearErrorEvent>(_clearError);
  }

  /// The serial number (GS1 application identifier 21) carried by a barcode,
  /// or '' when it has none. This is the only field a serial pattern can
  /// meaningfully be validated against.
  String _serialOf(GS1Barcode barcode) {
    try {
      final data = barcode.getAIsData;
      final serial = data['21'] ?? data['SERIAL'] ?? data['serial'];
      return serial?.toString().trim() ?? '';
    } catch (_) {
      // An unreadable barcode is not a pattern violation; let the rest of
      // the pipeline deal with it rather than silently dropping it here.
      return '';
    }
  }

  FutureOr<void> _clearError(
    DigitScannerClearErrorEvent event,
    DigitScannerEmitter emit,
  ) async {
    emit(state.copyWith(error: null));
  }

  FutureOr<void> _handleScanner(
    DigitScannerScanEvent event,
    DigitScannerEmitter emit,
  ) async {
    try {
      final hasContent = event.barCode.isNotEmpty ||
          event.qrCode.isNotEmpty ||
          event.manualCode.trim().isNotEmpty;

      // Build pattern only if provided and non-empty
      final shouldValidate =
          (event.regex != null && event.regex!.trim().isNotEmpty) && hasContent;

      if (!shouldValidate) {
        // No validation (no regex or no content)
        emit(state.copyWith(
          barCodes: event.barCode,
          qrCodes: event.qrCode,
          error: null,
          scannerId: event.scannerId,
        ));
        return;
      }

      final pattern = RegExp(event.regex!);

      // Validate GS1 barcodes against their SERIAL (AI 21), not the barcode
      // object.
      //
      // This used to test `b.toString()` - the whole GS1Barcode, GTIN, batch,
      // punctuation and all - against what is configured as a serial-number
      // pattern (e.g. the anchored "^[A-Z0-9][A-Z0-9-]{7,}$"). An anchored
      // serial pattern can never match a whole barcode, so EVERY scanned or
      // manually entered code was counted invalid. The consequences cascaded:
      // validBarcodes came out empty, the emit below replaced the captured
      // list with nothing, the form control the submit gate reads was
      // cleared, and Submit stayed disabled forever behind a repeating
      // "invalid code" toast - with the serial itself having been perfectly
      // valid all along.
      //
      // A barcode carrying no serial AI is left alone: a serial pattern has
      // nothing to say about it, and rejecting it is what caused this bug.
      final validBarcodes = <GS1Barcode>[];
      var invalidBarcodeCount = 0;
      for (final b in event.barCode) {
        final serial = _serialOf(b);
        if (serial.isEmpty || pattern.hasMatch(serial)) {
          validBarcodes.add(b);
        } else {
          invalidBarcodeCount++;
        }
      }

      // Validate QR codes (strings)
      final validQRCodes = <String>[];
      var invalidQRCodeCount = 0;
      for (final q in event.qrCode) {
        final qt = q.trim();
        if (qt.isNotEmpty && pattern.hasMatch(qt)) {
          validQRCodes.add(qt);
        } else if (qt.isNotEmpty) {
          invalidQRCodeCount++;
        }
      }

      // Manual code (optional); not stored but can contribute to error
      String? manualError;
      final mc = event.manualCode.trim();
      if (mc.isNotEmpty && !pattern.hasMatch(mc)) {
        manualError = 'Manual code rejected';
      }

      final anyInvalid =
          invalidBarcodeCount > 0 || invalidQRCodeCount > 0 || manualError != null;

      emit(state.copyWith(
        barCodes: validBarcodes,
        qrCodes: validQRCodes,
        error: anyInvalid
            ? (event.patternMessage != null && event.patternMessage!.trim().isNotEmpty)
                ? event.patternMessage!
                : _buildErrorMessage(
                    invalidBarcodesCount: invalidBarcodeCount,
                    invalidQRCodesCount: invalidQRCodeCount,
                    manualError: manualError,
                  )
            : null,
        scannerId: event.scannerId,
      ));
    } catch (error) {
      emit(state.copyWith(
        error: 'Unable to scan: ${error.toString()}',
        loading: false,
      ));
      return;
    } finally {
      emit(state.copyWith(loading: false));
    }
  }
  String _buildErrorMessage({
    required int invalidBarcodesCount,
    required int invalidQRCodesCount,
    String? manualError,
  }) {
    final parts = <String>[];
    if (invalidBarcodesCount > 0) parts.add('$invalidBarcodesCount barcode(s) rejected');
    if (invalidQRCodesCount > 0) parts.add('$invalidQRCodesCount QR code(s) rejected');
    if (manualError != null) parts.add(manualError);
    return parts.isEmpty ? '' : '${parts.join('. ')}.';
  }
}

@freezed
class DigitScannerEvent with _$DigitScannerEvent {
  const factory DigitScannerEvent.handleScanner({
    @Default([]) List<GS1Barcode> barCode,
    @Default([]) List<String> qrCode,
    @Default('') String manualCode,
    String? regex,
    String? patternMessage,
    /// Identifier for which scanner field initiated this scan.
    /// Used to prevent multiple scanner fields from reacting to the same state change.
    /// Defaults to 'default' for backward compatibility with existing flows.
    @Default('default') String scannerId,
  }) = DigitScannerScanEvent;

  /// Dismisses the current error without touching the captured codes.
  ///
  /// Callers used to clear an error by re-dispatching handleScanner with
  /// empty barCode/qrCode lists. That payload has no content, so
  /// _handleScanner takes its no-validation early return and emits those
  /// empty lists as the new state - silently discarding every serial the
  /// user had already captured, which left the delivery page's scan-limit
  /// gate permanently unsatisfied.
  const factory DigitScannerEvent.clearError() = DigitScannerClearErrorEvent;
}

@freezed
class DigitScannerState with _$DigitScannerState {
  const factory DigitScannerState({
    @Default([]) List<GS1Barcode> barCodes,
    @Default([]) List<String> qrCodes,
    @Default(false) bool loading,
    @Default(false) bool duplicate,
    String? error,
    /// Identifier for which scanner field this state belongs to.
    /// Used to filter state changes for specific scanner fields.
    /// Defaults to 'default' for backward compatibility.
    @Default('default') String scannerId,
  }) = _DigitScannerState;
}
