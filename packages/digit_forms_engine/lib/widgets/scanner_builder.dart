part of 'json_schema_builder.dart';

class JsonSchemaScannerBuilder extends JsonSchemaBuilder<String> {
  final DateTime? start;
  final DateTime? end;
  final bool summaryData;

  /// When true, the captured value is shown but the edit (pencil) affordance is
  /// hidden, so the scanned/prefilled code cannot be re-scanned or changed.
  /// Driven by the field's `readOnly` schema flag; defaults to false so every
  /// existing scanner field keeps its edit button.
  final bool readOnly;

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
    this.readOnly = false,
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

  bool get allowManual {
    bool defaultValue = true;
    if (validations != null &&
        validations!.any((v) => v.type == 'allowManual')) {
      return validations!.where((e) => e.type == 'allowManual').first.value ==
          true;
    } else {
      return defaultValue;
    }
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
          form.control(formControlName).value =
              DigitScannerUtils().serializeGs1Barcodes(state.barCodes);
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

        // Show barcode (GS1) summary
        return showBarcodeSummary
            ? Container(
                padding: EdgeInsets.zero,
                width: MediaQuery.of(context).size.width,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: isThisScanner && state.barCodes.isNotEmpty
                            // Use bloc state when available - show all barcodes
                            ? state.barCodes
                                .asMap()
                                .entries
                                .map((barcodeEntry) {
                                final index = barcodeEntry.key;
                                final gs1Data = DigitScannerUtils()
                                    .getGs1CodeFormattedStringAtIndex(
                                        state.barCodes, index);
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index < state.barCodes.length - 1
                                        ? 16.0
                                        : 0,
                                  ),
                                  child: LabelValueSummary(
                                    padding: EdgeInsets.zero,
                                    withDivider: false,
                                    items: gs1Data.entries.map((entry) {
                                      return LabelValueItem(
                                        labelFlex: 5,
                                        label: "GS1_${entry.key}",
                                        value: entry.value is DateTime
                                            ? DateFormat('d MMMM yyyy')
                                                .format(entry.value)
                                                .toString()
                                            : entry.value,
                                        maxLines: 5,
                                      );
                                    }).toList(),
                                  ),
                                );
                              }).toList()
                            // Fall back to parsing form value using deserializer
                            : () {
                                final parsedBarcodes =
                                    DigitScannerUtils.deserializeGs1Barcodes(
                                        formValue!);
                                final widgets = <Widget>[];
                                for (int i = 0;
                                    i < parsedBarcodes.length;
                                    i++) {
                                  final items = parsedBarcodes[i]
                                      .entries
                                      .map((entry) => LabelValueItem(
                                            labelFlex: 5,
                                            label: "GS1_${entry.key}",
                                            value: entry.value,
                                            maxLines: 5,
                                          ))
                                      .toList();
                                  widgets.add(Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i < parsedBarcodes.length - 1
                                          ? 16.0
                                          : 0,
                                    ),
                                    child: LabelValueSummary(
                                      padding: EdgeInsets.zero,
                                      withDivider: false,
                                      items: items,
                                    ),
                                  ));
                                }
                                return widgets;
                              }(),
                      ),
                    ),
                    if (!readOnly)
                      DigitButton(
                        label: '',
                        onPressed: () {
                          // Pass form value directly to scanner page via route param
                          // Scanner page will parse and dispatch to bloc in initState
                          final provider =
                              ScannerComparisonProvider.of(context);
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
                            allowManual: allowManual,
                            isEditEnabled: true,
                            initialBarcodeData: formValue,
                            scannerId: formControlName,
                            duplicateCheckFn: duplicateCheckFn,
                            duplicateCheckMessage: duplicateMsg,
                          ));
                        },
                        type: DigitButtonType.tertiary,
                        size: DigitButtonSize.medium,
                        prefixIcon: Icons.edit,
                      )
                  ],
                ),
              )
            // Show QR code summary
            : showQrSummary
                ? Container(
                    padding: EdgeInsets.zero,
                    width: MediaQuery.of(context).size.width,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * .78,
                          child: LabelValueSummary(
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
                        ),
                        if (!readOnly)
                          DigitButton(
                            label: '',
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
                              final provider2 =
                                  ScannerComparisonProvider.of(context);
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
                                allowManual: allowManual,
                                isEditEnabled: true,
                                initialQrCodes: displayQrCodes,
                                scannerId: formControlName,
                                duplicateCheckFn: duplicateCheckFn2,
                                duplicateCheckMessage: duplicateMsg2,
                              ));
                            },
                            type: DigitButtonType.tertiary,
                            size: DigitButtonSize.medium,
                            prefixIcon: Icons.edit,
                          )
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
                      final dupeFn3 = provider3 != null
                          ? provider3.duplicateCheckFn
                          : registry3.duplicateCheckFn;
                      final dupeErrFn3 = provider3 != null
                          ? provider3.duplicateErrorMessage
                          : registry3.duplicateErrorMessage;
                      final duplicateCheckFn3 = dupeFn3 != null
                          ? (String scannedValue) =>
                              dupeFn3(formControlName, scannedValue, form.value)
                          : null;
                      final duplicateMsg3 = dupeErrFn3?.call(formControlName);
                      context.router.push(DigitScannerRoute(
                        isGS1code: isGS1code,
                        allowManual: allowManual,
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
