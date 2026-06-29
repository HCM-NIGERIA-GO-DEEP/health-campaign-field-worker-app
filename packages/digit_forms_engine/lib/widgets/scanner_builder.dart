part of 'json_schema_builder.dart';

class JsonSchemaScannerBuilder extends JsonSchemaBuilder<String> {
  final DateTime? start;
  final DateTime? end;
  final bool summaryData;

  const JsonSchemaScannerBuilder({
    required super.formControlName,
    required super.form,
    super.label,
    super.key,
    super.value,
    super.helpText,
    this.start,
    this.end,
    super.validations,
    this.summaryData = false,
  });

  /// Converts ValidationRule list to ScannerValidation list
  List<ScannerValidation>? _toScannerValidations() {
    if (validations == null) return null;
    return validations!
        .map((v) => ScannerValidation(
              type: v.type,
              value: v.value,
              message: v.message,
            ))
        .toList();
  }

  bool get isGS1code {
    bool defaultValue = true;
    if (validations != null && validations!.any((v) => v.type == 'isGS1Code')) {
      return validations!.where((e) => e.type == 'isGS1Code').first.value ==
          true;
    } else {
      return defaultValue;
    }
  }

  String formatDisplayCodes(List displayCodes) {
    if (displayCodes.isEmpty) return '';
    // If it's a single code, display as is
    if (displayCodes.length == 1 && displayCodes.first.contains('||')) {
      return displayCodes.first.toString().split("||").first.trim();
    }
    // If multiple codes, join with comma and space
    return displayCodes.map((e) => e.toString()).join(', ');
  }

  String _extractSerialFromGs1Map(Map<String, dynamic> data) {
    final serial =
        data['21'] ?? data['SERIAL'] ?? data['serial'] ?? data['Serial'];
    return serial?.toString().trim() ?? '';
  }

  List<String> _serialsFromFormValue(String data) {
    final parsed = DigitScannerUtils.deserializeGs1Barcodes(data);
    return parsed
        .map((e) => _extractSerialFromGs1Map(e))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _mergeBarcodeValues(String? existingValue, String incomingValue) {
    if (incomingValue.trim().isEmpty) return existingValue ?? '';
    if (existingValue == null || existingValue.trim().isEmpty) {
      return incomingValue;
    }

    final existingMaps = DigitScannerUtils.deserializeGs1Barcodes(existingValue);
    final incomingMaps = DigitScannerUtils.deserializeGs1Barcodes(incomingValue);
    final combined = <Map<String, String>>[...existingMaps, ...incomingMaps];

    final seen = <String>{};
    final unique = <Map<String, String>>[];
    for (final map in combined) {
      final sortedKeys = map.keys.toList()..sort();
      final signature =
          sortedKeys.map((k) => '$k:${map[k] ?? ''}').join('|');
      if (signature.isEmpty || seen.contains(signature)) continue;
      seen.add(signature);
      unique.add(map);
    }

    return unique
        .map((m) => m.entries
            .where((e) => e.value.trim().isNotEmpty)
            .map((e) => '${e.key}:${e.value}')
            .join('|'))
        .where((e) => e.isNotEmpty)
        .join(';');
  }

  @override
  Widget build(BuildContext context) {
    final loc = FormLocalization.of(context);
    final validationMessages = buildValidationMessages(validations, loc);
    return ReactiveWrapperField(
      formControlName: formControlName,
      validationMessages: validationMessages,
      showErrors: (control) => control.invalid && control.touched,
      builder: (field) => BlocConsumer<DigitScannerBloc, DigitScannerState>(
          listenWhen: (previous, current) {
        // Only listen if this scanner initiated the scan
        return current.scannerId == formControlName;
      }, buildWhen: (previous, current) {
        // Only rebuild if this scanner initiated the scan
        return current.scannerId == formControlName;
      }, listener: (context, state) {
        if (state.qrCodes.isNotEmpty) {
          // Join multiple QR codes with comma separator
          form.control(formControlName).value = state.qrCodes.join(', ');
        } else if (state.barCodes.isNotEmpty) {
          // Serialize barcodes dynamically using only non-empty fields
          final incomingValue =
              DigitScannerUtils().serializeGs1Barcodes(state.barCodes);
          final existingValue = form.control(formControlName).value as String?;
          form.control(formControlName).value =
              _mergeBarcodeValues(existingValue, incomingValue);
        } else {
          // Clear the form value when all scanned data has been deleted
          form.control(formControlName).value = null;
        }
      }, builder: (context, state) {
        // Check if this scanner initiated the scan OR if form has pre-populated data
        final isThisScanner = state.scannerId == formControlName;
        final formValue = form.control(formControlName).value as String?;
        final hasFormValue = formValue != null && formValue.isNotEmpty;

        // Sync form value with state when returning from scanner page
        // The listener may miss state changes that happen during navigation
        if (isThisScanner && state.qrCodes.isNotEmpty) {
          final stateValue = state.qrCodes.join(', ');
          if (formValue != stateValue) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              form.control(formControlName).value = stateValue;
            });
          }
        } else if (isThisScanner && state.barCodes.isNotEmpty) {
          // Sync barcodes - build expected form value and compare
          final stateValue =
              DigitScannerUtils().serializeGs1Barcodes(state.barCodes);
          if (formValue != stateValue) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              form.control(formControlName).value = stateValue;
            });
          }
        } else if (isThisScanner &&
            state.qrCodes.isEmpty &&
            state.barCodes.isEmpty &&
            hasFormValue) {
          // Clear form value when all scanned data has been deleted
          WidgetsBinding.instance.addPostFrameCallback((_) {
            form.control(formControlName).value = null;
          });
        }

        // Check if this is barcode data (GS1 format)
        // New format: key:value|key:value (pipe-separated key-value pairs)
        // Legacy format: GTIN,SERIAL,BATCH,EXPIRY (4 comma-separated parts)
        bool isGS1BarcodeFormat(String value) {
          if (value.contains("||")) {
            return false; // Invalid if double pipe exists
          }
          // New format: contains '|' or starts with 2-digit AI code followed by ':'
          if (value.contains('|') ||
              RegExp(r'^\d{2}:').hasMatch(value.trim())) {
            return true;
          }
          // Legacy format: check for semicolon-separated barcodes
          if (value.contains(';')) {
            final barcodes = value.split(';');
            final firstParts =
                barcodes.first.split(',').map((e) => e.trim()).toList();
            return firstParts.length == 4;
          }
          // Single legacy barcode check
          final parts = value.split(',').map((e) => e.trim()).toList();
          return parts.length == 4;
        }

        final isBarcodeData = (isThisScanner && state.barCodes.isNotEmpty) ||
            (hasFormValue && isGS1BarcodeFormat(formValue));

        // Use bloc state qrCodes if this scanner just scanned, otherwise parse from form value
        // QR codes are comma-separated
        final displayQrCodes = isThisScanner && state.qrCodes.isNotEmpty
            ? state.qrCodes
            : (!isBarcodeData && hasFormValue
                ? formValue
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList()
                : <String>[]);

        // Show barcode summary first (if barcode data exists), then QR summary
        final showBarcodeSummary = isBarcodeData && summaryData;
        final showQrSummary =
            !showBarcodeSummary && displayQrCodes.isNotEmpty && summaryData;

        final displaySerials = isThisScanner && state.barCodes.isNotEmpty
          ? state.barCodes
            .asMap()
            .entries
            .map((barcodeEntry) {
              final gs1Data = DigitScannerUtils()
                .getGs1CodeFormattedStringAtIndex(
                  state.barCodes, barcodeEntry.key);
              return _extractSerialFromGs1Map(gs1Data);
            })
            .where((e) => e.isNotEmpty)
            .toList()
          : (hasFormValue ? _serialsFromFormValue(formValue!) : <String>[]);


        // Show barcode (GS1) summary
        return showBarcodeSummary
            ? Container(
                padding: EdgeInsets.zero,
                width: MediaQuery.of(context).size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabelValueSummary(
                      padding: EdgeInsets.zero,
                      withDivider: false,
                      items: displaySerials
                          .map(
                            (serial) => LabelValueItem(
                              labelFlex: 5,
                              label: 'Serial Number',
                              value: serial,
                              maxLines: 2,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    DigitButton(
                      capitalizeLetters: false,
                      size: DigitButtonSize.large,
                      label: label ?? 'scanner',
                      onPressed: () {
                        // Pass form value directly to scanner page via route param
                        // Scanner page will parse and dispatch to bloc in initState
                        final provider = ScannerComparisonProvider.of(context);
                        final registry = ScannerComparisonRegistry();
                        final dupeFn = provider != null
                            ? provider.duplicateCheckFn
                            : registry.duplicateCheckFn;
                        final dupeErrFn = provider != null
                            ? provider.duplicateErrorMessage
                            : registry.duplicateErrorMessage;
                        final duplicateCheckFn = dupeFn != null
                            ? (String scannedValue) => dupeFn(
                                  formControlName, scannedValue, form.value)
                            : null;
                        final duplicateMsg = dupeErrFn?.call(formControlName);
                        context.router.push(DigitScannerRoute(
                          validations: _toScannerValidations(),
                          isGS1code: isGS1code,
                          isEditEnabled: true,
                          initialBarcodeData: formValue,
                          scannerId: formControlName,
                          duplicateCheckFn: duplicateCheckFn,
                          duplicateCheckMessage: duplicateMsg,
                        ));
                      },
                      type: DigitButtonType.secondary,
                      prefixIcon: Icons.qr_code,
                      mainAxisSize: MainAxisSize.max,
                    ),
                  ],
                ),
              )
            // Show QR code summary
            : showQrSummary
                ? Container(
                    padding: EdgeInsets.zero,
                    width: MediaQuery.of(context).size.width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LabelValueSummary(
                          padding: EdgeInsets.zero,
                          withDivider: false,
                          items: [
                            LabelValueItem(
                              label: label ?? 'Voucher code',
                              // Show all QR codes comma-separated
                              value: formatDisplayCodes(displayQrCodes),
                              labelFlex: 5,
                              maxLines: 5,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DigitButton(
                          capitalizeLetters: false,
                          size: DigitButtonSize.large,
                          label: label ?? 'scanner',
                          onPressed: () {
                            // Clear scanner state before navigating to edit QR codes
                            context.read<DigitScannerBloc>().add(
                                  DigitScannerEvent.handleScanner(
                                    barCode: [],
                                    qrCode: [],
                                    scannerId: formControlName,
                                  ),
                                );
                            // Use displayQrCodes which already has the parsed data
                            final provider2 = ScannerComparisonProvider.of(context);
                            final registry2 = ScannerComparisonRegistry();
                            final dupeFn2 = provider2 != null
                                ? provider2.duplicateCheckFn
                                : registry2.duplicateCheckFn;
                            final dupeErrFn2 = provider2 != null
                                ? provider2.duplicateErrorMessage
                                : registry2.duplicateErrorMessage;
                            final duplicateCheckFn2 = dupeFn2 != null
                                ? (String scannedValue) => dupeFn2(
                                      formControlName, scannedValue, form.value)
                                : null;
                            final duplicateMsg2 =
                                dupeErrFn2?.call(formControlName);
                            context.router.push(DigitScannerRoute(
                              validations: _toScannerValidations(),
                              isGS1code: isGS1code,
                              isEditEnabled: true,
                              initialQrCodes: displayQrCodes,
                              scannerId: formControlName,
                              duplicateCheckFn: duplicateCheckFn2,
                              duplicateCheckMessage: duplicateMsg2,
                            ));
                          },
                          type: DigitButtonType.secondary,
                          prefixIcon: Icons.qr_code,
                          mainAxisSize: MainAxisSize.max,
                        ),
                      ],
                    ),
                  )
                // Show scan button (no data yet)
                : DigitButton(
                    capitalizeLetters: false,
                    size: DigitButtonSize.large,
                    label: label ?? 'scanner',
                    onPressed: () async {
                      context.read<DigitScannerBloc>().add(
                            DigitScannerEvent.handleScanner(
                              scannerId: formControlName,
                            ),
                          );
                      final provider3 = ScannerComparisonProvider.of(context);
                      final registry3 = ScannerComparisonRegistry();
                      final dupeFn3 = provider3 != null ? provider3.duplicateCheckFn : registry3.duplicateCheckFn;
                      final dupeErrFn3 = provider3 != null ? provider3.duplicateErrorMessage : registry3.duplicateErrorMessage;
                      final duplicateCheckFn3 = dupeFn3 != null
                          ? (String scannedValue) => dupeFn3(
                                formControlName, scannedValue, form.value)
                          : null;
                      final duplicateMsg3 = dupeErrFn3?.call(formControlName);
                      context.router.push(DigitScannerRoute(
                        isGS1code: isGS1code,
                        validations: _toScannerValidations(),
                        scannerId: formControlName,
                        duplicateCheckFn: duplicateCheckFn3,
                        duplicateCheckMessage: duplicateMsg3,
                      ));
                    },
                    type: DigitButtonType.secondary,
                    prefixIcon: Icons.qr_code,
                    mainAxisSize: MainAxisSize.max,
                  );
      }),
    );
  }
}
