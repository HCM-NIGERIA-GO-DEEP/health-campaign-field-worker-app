part of 'json_schema_builder.dart';

class JsonSchemaScannerBuilder extends JsonSchemaBuilder<String> {
  final DateTime? start;
  final DateTime? end;
  final bool summaryData;
  final Map<String, dynamic>? navigationParams;

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
    this.navigationParams,
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

  int? get scanLimit {
    if (validations == null) return null;

    for (final rule in validations!) {
      if (rule.type != 'scanLimit') continue;

      final value = rule.value;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
    }

    return null;
  }

  int? _distributedQuantityFromResourceCard(FormGroup form) {
    if (!form.contains('resourceCard')) return null;

    final dynamic value = form.control('resourceCard').value;
    if (value == null) return null;

    int total = 0;

    if (value is List) {
      for (final item in value) {
        if (item is Map) {
          final q = item['quantityDistributed'];
          if (q is int) {
            total += q;
          } else if (q is String) {
            total += int.tryParse(q) ?? 0;
          }
        }
      }
    } else if (value is Map) {
      final q = value['quantityDistributed'];
      if (q is int) {
        total += q;
      } else if (q is String) {
        total += int.tryParse(q) ?? 0;
      }
    }

    return total > 0 ? total : null;
  }

  int _effectiveRequiredScanCount(FormGroup form) {
    final configured = scanLimit ?? 1;
    if (!isGS1code) return configured;

    final fromResourceCard = _distributedQuantityFromResourceCard(form);
    return fromResourceCard ?? configured;
  }

  List<ScannerValidation>? _resolvedScannerValidations(int requiredScanCount) {
    final source = _toScannerValidations();
    if (source == null) {
      return [
        ScannerValidation(type: 'scanLimit', value: requiredScanCount),
      ];
    }

    var replaced = false;
    final updated = source.map((v) {
      if (v.type == 'scanLimit') {
        replaced = true;
        return ScannerValidation(
          type: v.type,
          value: requiredScanCount,
          message: v.message,
        );
      }
      return v;
    }).toList();

    if (!replaced) {
      updated.add(
        ScannerValidation(type: 'scanLimit', value: requiredScanCount),
      );
    }

    return updated;
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

  dynamic _readPathValue(dynamic root, List<String> pathParts) {
    dynamic current = root;

    for (final part in pathParts) {
      if (current == null) return null;

      if (current is Map) {
        if (current.containsKey(part)) {
          current = current[part];
          continue;
        }

        final asInt = int.tryParse(part);
        if (asInt != null && current.containsKey(asInt)) {
          current = current[asInt];
          continue;
        }

        return null;
      }

      if (current is List) {
        final index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) {
          return null;
        }
        current = current[index];
        continue;
      }

      return null;
    }

    return current;
  }

  String? _cleanNamePart(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    final lower = trimmed.toLowerCase();
    if (trimmed.isEmpty ||
        trimmed == '--' ||
        lower == 'null' ||
        lower == 'beneficiary' ||
        lower == 'name') {
      return null;
    }
    return trimmed;
  }

  String? _composeName(String? first, String? last) {
    final parts =
        [first, last].where((e) => e != null && e.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String? _nameFromRoot(dynamic root) {
    final first =
        _cleanNamePart(_readPathValue(root, const ['nameOfIndividual'])) ??
            _cleanNamePart(_readPathValue(root, const ['firstName'])) ??
            _cleanNamePart(_readPathValue(root, const ['givenName'])) ??
            _cleanNamePart(_readPathValue(root, const [
              'contextData',
              '0',
              'headIndividual',
              'IndividualModel',
              'name',
              'givenName',
            ]));

    final last = _cleanNamePart(_readPathValue(root, const ['lastName'])) ??
        _cleanNamePart(_readPathValue(root, const ['familyName'])) ??
        _cleanNamePart(_readPathValue(root, const [
          'contextData',
          '0',
          'headIndividual',
          'IndividualModel',
          'name',
          'additionalFields',
          'fields',
          'lastName',
        ]));

    final full = _composeName(first, last);
    if (full != null) return full;
    return first;
  }

  String? _beneficiaryNameFromForm(BuildContext context, FormGroup form) {
    final fromFormValue = _nameFromRoot(form.value);
    if (fromFormValue != null) return fromFormValue;

    final fromNavigation = _nameFromRoot(navigationParams);
    if (fromNavigation != null) return fromNavigation;

    try {
      final defaults = context.read<Map<String, dynamic>>();
      final fromDefaults = _nameFromRoot(defaults);
      if (fromDefaults != null) return fromDefaults;
    } catch (_) {
      // No default values provider available.
    }

    return null;
  }

  String _deliveryInstructionMessage(
    BuildContext context,
    FormGroup form,
    int requiredScanCount,
  ) {
    final beneficiaryName =
        _beneficiaryNameFromForm(context, form) ?? 'beneficiary';
    final bednetLabel = requiredScanCount == 1 ? 'ITN' : 'ITNs';

    return 'Ensure that "$requiredScanCount $bednetLabel" are given to '
        '"$beneficiaryName" and proper Health Talk is provided!';
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

        final requiredScanCount = _effectiveRequiredScanCount(form);
        final currentScanCount = isGS1code ? displaySerials.length : displayQrCodes.length;
        final canOpenScanner = currentScanCount < requiredScanCount;
        final resolvedValidations =
            _resolvedScannerValidations(requiredScanCount);


        final showDeliveryInstructionBanner =
            summaryData && isGS1code && form.contains('resourceCard');
        final deliveryInstructionMessage = _deliveryInstructionMessage(
          context,
          form,
          requiredScanCount,
        );

        // Show barcode (GS1) summary
        final scannerContent = showBarcodeSummary
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
                      isDisabled: !canOpenScanner,
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
                          quantity: requiredScanCount,
                          validations: resolvedValidations,
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
                          isDisabled: !canOpenScanner,
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
                              quantity: requiredScanCount,
                              validations: resolvedValidations,
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
                  isDisabled: !canOpenScanner,
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
                        quantity: requiredScanCount,
                        isGS1code: isGS1code,
                        validations: resolvedValidations,
                        scannerId: formControlName,
                        duplicateCheckFn: duplicateCheckFn3,
                        duplicateCheckMessage: duplicateMsg3,
                      ));
                    },
                    type: DigitButtonType.secondary,
                    prefixIcon: Icons.qr_code,
                    mainAxisSize: MainAxisSize.max,
                  );

        return _DeliveryInstructionWrapper(
          showBanner: showDeliveryInstructionBanner,
          message: deliveryInstructionMessage,
          child: scannerContent,
        );
      }),
    );
  }
}

class _DeliveryInstructionWrapper extends StatefulWidget {
  final bool showBanner;
  final String message;
  final Widget child;

  const _DeliveryInstructionWrapper({
    required this.showBanner,
    required this.message,
    required this.child,
  });

  @override
  State<_DeliveryInstructionWrapper> createState() =>
      _DeliveryInstructionWrapperState();
}

class _DeliveryInstructionWrapperState
    extends State<_DeliveryInstructionWrapper> {
  bool _dismissed = false;

  @override
  void didUpdateWidget(covariant _DeliveryInstructionWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Re-show banner when message context changes.
    if (oldWidget.message != widget.message && _dismissed) {
      _dismissed = false;
    }

    if (!oldWidget.showBanner && widget.showBanner && _dismissed) {
      _dismissed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showBanner || _dismissed) {
      return widget.child;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          color: const Color(0xFFC4452D),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.error_outline,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _dismissed = true;
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        widget.child,
      ],
    );
  }
}
