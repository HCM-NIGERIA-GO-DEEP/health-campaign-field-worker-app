part of 'json_schema_builder.dart';

class JsonFormBuilder extends LocalizedStatefulWidget {
  final String formControlName;
  final PropertySchema schema;
  final List<Map<String, Widget>>? components;
  final String pageName;
  final String currentSchemaKey;
  final Map<String, dynamic>? navigationParams;

  const JsonFormBuilder({
    super.key,
    super.appLocalizations,
    required this.formControlName,
    required this.schema,
    this.components,
    required this.pageName,
    required this.currentSchemaKey,
    this.navigationParams,
  });

  @override
  State<JsonFormBuilder> createState() => _JsonFormBuilderState();
}

class _JsonFormBuilderState extends LocalizedState<JsonFormBuilder> {
  bool _autoReadOnly = false; // ← runtime overlay

  @override
  Widget build(BuildContext context) {
    final form = ReactiveForm.of(context) as FormGroup;

    // Handle conditional display logic
    if (_shouldHideField(form, widget.schema, widget.formControlName)) {
      // A hidden latLng field must still mount so it can capture the device
      // location into the form control (consumed by transformers, e.g. to save
      // lat/long on a Task during delivery). Render it silently/offstage.
      if (widget.schema.format == PropertySchemaFormat.latLng &&
          form.contains(widget.formControlName)) {
        return Offstage(
          offstage: true,
          child: JsonSchemaLatLngBuilder(
            formControlName: widget.formControlName,
            form: form,
            silent: true,
          ),
        );
      }
      return const SizedBox.shrink();
    }

    _checkAutoFill(form);

    // Stable identifier (surfaces as Android resource-id = formControlName)
    // so UI-test selectors survive campaign label changes. This is the live
    // per-field dispatch point - BaseReactiveFieldWrapper is not referenced
    // anywhere on this branch, so instrumenting it never reached the screen
    // (proven by run -0108: zero resource-ids on the Beneficiary Location
    // form page).
    return Semantics(
      identifier: widget.formControlName,
      child: _buildByType(form),
    );
  }

  bool get _isReadOnly => (widget.schema.readOnly ?? false) || _autoReadOnly;

  void _checkAutoFill(FormGroup form) {
    final autoFillConditions = widget.schema.autoFillCondition;

    if (autoFillConditions == null || autoFillConditions.isEmpty) return;

    // Skip if control doesn't exist (hidden field without includeInForm: true)
    if (!form.contains(widget.formControlName)) return;

    final formState = context.read<FormsBloc>().state;
    final currentPageKey = widget.pageName;
    final currentSchemaKey = widget.currentSchemaKey;

    final values = buildVisibilityEvaluationContext(
      currentPageKey: currentPageKey,
      currentForm: form,
      pages: formState.cachedSchemas[currentSchemaKey]!.pages,
      navigationParams: widget.navigationParams,
    );

    bool matched = false;

    for (final condition in autoFillConditions) {
      // Resolve dynamic variables in expression before evaluation
      final resolvedExpression = _resolveDynamicVariables(condition.expression);
      final result = evaluateSingleCondition(resolvedExpression, values);
      if (result) {
        matched = true;

        // Access defaultValues via Provider
        final defaultValues = context.read<Map<String, dynamic>>();

        final key = _stripCurlyBraces(condition.value);

        // Resolve value from both form controls and defaultValues
        // Supports array index notation: "scannedData_$tabIndex[0]"
        // nested paths: "stockProductDetails.scannedData_0"
        // and defaultValues: "selectedProduct"
        final filledValue = _resolveAutoFillValue(key, form, defaultValues);

        if (filledValue != null && filledValue != "") {
          dynamic valueToSet = filledValue;

          // If filledValue is a string like "20 Jun 2025", convert to DateTime
          if (filledValue is String) {
            try {
              final currentLocale = Localizations.localeOf(context).toString();
              valueToSet = DateFormat("dd MMM yyyy", currentLocale)
                  .parseStrict(filledValue);
            } catch (_) {
              // Not a date string → keep as string
              valueToSet = filledValue;
            }
          }

          // Only set value if it's different from current to prevent rebuild loops
          final currentValue = form.control(widget.formControlName).value;
          if (currentValue != valueToSet) {
            form.control(widget.formControlName).value = valueToSet;
          }
          _autoReadOnly = true;
        }

        /// make field as non editable

        break;
      }
    }

    if (!matched && _autoReadOnly) {
      // Condition not met — reset to default
      // Only set value if it's different from current to prevent rebuild loops
      final currentValue = form.control(widget.formControlName).value;
      if (currentValue != widget.schema.value) {
        form.control(widget.formControlName).value = widget.schema.value;
      }
      _autoReadOnly = widget.schema.readOnly ?? false; // ← back to editable
    }
  }

  String _stripCurlyBraces(String value) {
    final regex = RegExp(r'^\{\{(.+)\}\}$'); // Matches {{...}}
    final match = regex.firstMatch(value.trim());
    return match != null
        ? match.group(1)!
        : value; // Return inside if matched, else original
  }

  /// Resolve dynamic variables in the path (e.g., $tabIndex, $entityIndex)
  String _resolveDynamicVariables(String path) {
    String resolvedPath = path;

    // Get current entity index from navigationParams if available
    final currentEntityIndex = widget.navigationParams?['currentEntityIndex'];

    // Replace $tabIndex or $entityIndex with actual index
    // Uses '_item_N' suffix to match form control naming convention
    // Example: scanResource_$tabIndex -> scanResource_item_0
    if (currentEntityIndex != null) {
      resolvedPath = resolvedPath
          .replaceAll(r'_$tabIndex', '_item_$currentEntityIndex')
          .replaceAll(r'_$entityIndex', '_item_$currentEntityIndex')
          .replaceAll(r'_$index', '_item_$currentEntityIndex');
    }

    return resolvedPath;
  }

  /// Unified autoFill value resolver supporting both form controls and defaultValues
  /// Supports:
  /// - Array index: "scannedData_0[1]" to access index 1 of comma-separated string
  /// - Nested paths from form: "stockProductDetails.scannedData_0"
  /// - Nested paths from defaultValues: "formData.selectedProduct"
  /// - Dynamic variables: "scannedData_$tabIndex[0]"
  /// - Simple keys from defaultValues: "selectedProduct"
  dynamic _resolveAutoFillValue(
    String path,
    FormGroup form,
    Map<String, dynamic> defaultValues,
  ) {
    // First resolve dynamic variables
    final resolvedPath = _resolveDynamicVariables(path);

    // Function call support: "fn:functionName(arg1, arg2, ...)"
    // Lets a field derive its auto-fill value from a registered method
    // (e.g. fn:calculateWastage(quantityPartialUsed_$tabIndex, quantityUnused_$tabIndex)).
    if (resolvedPath.startsWith('fn:')) {
      return _resolveFunctionValue(
          resolvedPath.substring(3), form, defaultValues);
    }

    // Regex to match something like:  abc[0]  or  stockProductDetails_0[2]
    final arrayIndexPattern = RegExp(r'^(.*)\[(\d+)\]$');
    final match = arrayIndexPattern.firstMatch(resolvedPath);

    if (match != null) {
      final key = match.group(1)!; // before [ ]
      final index = int.parse(match.group(2)!); // inside [ ]

      // 1️⃣ Get the raw value from form (NO dot resolution)
      dynamic raw;
      if (form.contains(key)) {
        raw = form.control(key).value;
      } else {
        raw = defaultValues[key];
      }

      // 2️⃣ If the raw value is a list → return list[index]
      if (raw is List) {
        if (index < raw.length) return raw[index];
        return null;
      }

      // 3️⃣ If raw is a string (comma-separated) → split and return index
      if (raw is String) {
        final parts = raw.split(',');
        if (index < parts.length) return parts[index].trim();
        return null;
      }

      return null;
    }

    // If no [index], return directly (NO dot resolution)
    if (form.contains(resolvedPath)) {
      return form.control(resolvedPath).value;
    }

    return defaultValues[resolvedPath];
  }

  /// Evaluate a function-call auto-fill value such as
  /// `calculateWastage(quantityPartialUsed_item_0, quantityUnused_item_0)`
  /// using the forms-engine [functionRegistry]. Each argument is resolved from
  /// form controls first, then defaultValues, then parsed as a string literal
  /// or number. Returns null if the function isn't registered.
  dynamic _resolveFunctionValue(
    String call,
    FormGroup form,
    Map<String, dynamic> defaultValues,
  ) {
    final match = RegExp(r'^(\w+)\((.*)\)$').firstMatch(call.trim());
    if (match == null) return null;

    final fn = functionRegistry[match.group(1)];
    if (fn == null) return null;

    final rawArgs = match.group(2)!.trim();
    final args = rawArgs.isEmpty
        ? const <dynamic>[]
        : rawArgs.split(',').map((arg) {
            final key = arg.trim();
            if (form.contains(key)) return form.control(key).value;
            if (defaultValues.containsKey(key)) return defaultValues[key];
            // String literal
            if ((key.startsWith('"') && key.endsWith('"')) ||
                (key.startsWith("'") && key.endsWith("'"))) {
              return key.substring(1, key.length - 1);
            }
            // Navigation params (supports nested dot paths, e.g. currentEntity.id)
            final navValue = _resolveFromNavigationParams(key);
            if (navValue != null) return navValue;
            // Number literal, else the raw token
            return num.tryParse(key) ?? key;
          }).toList();

    return fn(args);
  }

  /// Resolve a (possibly dotted) key from this field's navigationParams,
  /// e.g. "stockBalances" or "currentEntity.id". Returns null if not found.
  dynamic _resolveFromNavigationParams(String key) {
    final navParams = widget.navigationParams;
    if (navParams == null) return null;

    dynamic current = navParams;
    for (final part in key.split('.')) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Resolve a nested path from form controls (e.g., "stockProductDetails.scannedData_0")
  dynamic _resolveNestedPathFromForm(String path, FormGroup form) {
    final parts = path.split('.');
    dynamic current = form;

    for (final part in parts) {
      if (current is FormGroup && current.contains(part)) {
        current = current.control(part);
      } else {
        return null;
      }
    }

    // Return the value of the final control
    return current is AbstractControl ? current.value : null;
  }

  /// Resolve a nested path from a map (e.g., "scannedData.01 (GTIN)")
  /// Supports dynamic variables like scannedData_$tabIndex.fieldName
  dynamic _resolveNestedPath(String path, Map<String, dynamic> data) {
    // First resolve any dynamic variables in the path
    final resolvedPath = _resolveDynamicVariables(path);

    // Handle dotted paths by splitting on dots
    final parts = resolvedPath.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
        if (current == null) return null;
      } else if (current is Map) {
        // Handle Map (non-String keys) - convert to Map<String, dynamic>
        current = current[part];
        if (current == null) return null;
      } else {
        return null;
      }
    }

    // Convert DateTime to string format if needed
    if (current is DateTime) {
      return DateFormat('yyyy-MM-dd').format(current);
    }

    return current;
  }

  /// Conditionally hide based on display behavior
  bool _shouldHideField(
      FormGroup form, PropertySchema schema, String formName) {
    final hidden = schema.hidden;
    if (hidden != null && hidden == true) return true;

    final visibility = schema.visibilityCondition;
    if (visibility != null && visibility.expression.isNotEmpty) {
      final formState = context.read<FormsBloc>().state;
      final currentPageKey = widget.pageName;

      final currentSchemaKey = widget.currentSchemaKey;

      final values = buildVisibilityEvaluationContext(
        currentPageKey: currentPageKey,
        currentForm: form,
        pages: formState.cachedSchemas[currentSchemaKey]!.pages,
        navigationParams: widget.navigationParams,
      );

      final result =
          evaluateVisibilityExpression(visibility.expression, values);
      VisibilityManager(
        schemaMap: {formName: schema},
        formData: form.rawValue,
        form: form,
        navigationParams: widget.navigationParams,
      ).toggleControlVisibility(formName, result, widget.schema);

      return !result;
    }

    return false;
  }

  /// Dispatch to builder based on property type
  Widget _buildByType(FormGroup form) {
    switch (widget.schema.type) {
      case PropertySchemaType.string:
        return _buildStringType(form);
      case PropertySchemaType.integer:
        return _buildIntegerType(form);
      case PropertySchemaType.boolean:
        return _buildBooleanType(form);
      case PropertySchemaType.object:
        return _buildObjectType(form);
      case PropertySchemaType.dynamic:
        return _buildCustomComponent() ?? const SizedBox.shrink();
    }
  }

  int? _safeTimestamp(String type) {
    final v = widget.schema.validations
        ?.firstWhereOrNull((item) => item.type == type)
        ?.value;

    if (v == null) return null;
    if (v is! int) return null; // avoid type mismatch

    return v;
  }

  /// Handle `string` type formats
  Widget _buildStringType(FormGroup form) {
    final format = widget.schema.format;

    switch (format) {
      case PropertySchemaFormat.select:
        return LabeledField(
          infoText: translateIfPresent(widget.schema.tooltip, localizations),
          isRequired: hasRequiredValidation(widget.schema.validations),
          label: translateIfPresent(widget.schema.label, localizations),
          child: JsonSchemaSelectionBuilder(
            form: form,
            isMultiSelect: widget.schema.isMultiSelect,
            formControlName: widget.formControlName,
            enums: widget.schema.enums ?? [],
            validations: widget.schema.validations,
          ),
        );

      case PropertySchemaFormat.idPopulator:
        return JsonSchemaIdPopulatorBuilder(
          form: form,
          label: translateIfPresent(widget.schema.label, localizations),
          isRequired: hasRequiredValidation(widget.schema.validations),
          formControlName: widget.formControlName,
          enums: widget.schema.enums ?? [],
          validations: widget.schema.validations,
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          innerLabel:
              translateIfPresent(widget.schema.innerLabel, localizations),
        );

      case PropertySchemaFormat.dropdown:
        return JsonSchemaDropdownBuilder(
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          isRequired: hasRequiredValidation(widget.schema.validations),
          label: translateIfPresent(widget.schema.label, localizations),
          form: form,
          formControlName: widget.formControlName,
          enums: widget.schema.enums ?? [],
          validations: widget.schema.validations,
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          isMultiselect: widget.schema.isMultiSelect ?? false,
          readOnly: _isReadOnly,
        );

      case PropertySchemaFormat.mobileNumber:
        return JsonSchemaStringBuilder(
          form: form,
          label: translateIfPresent(widget.schema.label, localizations),
          formControlName: widget.formControlName,
          inputType: TextInputType.number,
          readOnly: _isReadOnly,
          validations: widget.schema.validations,
          isRequired: hasRequiredValidation(widget.schema.validations),
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          innerLabel:
              translateIfPresent(widget.schema.innerLabel, localizations),
          prefixText:
              translateIfPresent(widget.schema.prefixText, localizations),
        );

      case PropertySchemaFormat.dob:
        return JsonSchemaDOBBuilder(
          label: translateIfPresent(widget.schema.label, localizations),
          form: form,
          formControlName: widget.formControlName,
          validations: widget.schema.validations,
          navigationParams: widget.navigationParams,
          initialDate: _safeTimestamp("startDate") != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  _safeTimestamp("startDate")!)
              : null,
        );

      case PropertySchemaFormat.scanner:
        return JsonSchemaScannerBuilder(
          form: form,
          value: widget.schema.value as String?,
          formControlName: widget.formControlName,
          label: translateIfPresent(widget.schema.label, localizations),
          validations: widget.schema.validations,
          summaryData: widget.schema.includeInSummary ?? true,
        );

      case PropertySchemaFormat.date:
        return JsonSchemaDatePickerBuilder(
          isRequired: hasRequiredValidation(widget.schema.validations),
          readOnly: _isReadOnly,
          innerLabel:
              translateIfPresent(widget.schema.innerLabel, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          label: translateIfPresent(widget.schema.label, localizations),
          form: form,
          formControlName: widget.formControlName,
          start: _safeTimestamp("startDate") != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  _safeTimestamp("startDate")!)
              : null,
          end: _safeTimestamp("endDate") != null
              ? DateTime.fromMillisecondsSinceEpoch(_safeTimestamp("endDate")!)
              : null,
          validations: widget.schema.validations,
          helpText: translateIfPresent(widget.schema.helpText, localizations),
        );

      case PropertySchemaFormat.locality:
        return JsonSchemaStringBuilder(
          form: form,
          isRequired: hasRequiredValidation(widget.schema.validations),
          value: widget.schema.value as String?,
          formControlName: widget.formControlName,
          readOnly: true,
          label: translateIfPresent(widget.schema.label, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          helpText: translateIfPresent(widget.schema.helpText, localizations),
        );

      case PropertySchemaFormat.radio:
        return JsonSchemaRadioBuilder(
          form: form,
          formControlName: widget.formControlName,
          validations: widget.schema.validations,
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          label: translateIfPresent(widget.schema.label, localizations),
          enums: widget.schema.enums ?? [],
        );

      case PropertySchemaFormat.custom:
        return _buildCustomComponent() ?? const SizedBox.shrink();

      case PropertySchemaFormat.latLng:
        return JsonSchemaLatLngBuilder(
          formControlName: widget.formControlName,
          form: form,
          isRequired: hasRequiredValidation(widget.schema.validations),
          label: translateIfPresent(widget.schema.label, localizations),
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
        );

      case PropertySchemaFormat.textArea:
        return JsonSchemaTextAreaBuilder(
          form: form,
          label: translateIfPresent(widget.schema.label, localizations),
          formControlName: widget.formControlName,
          value: widget.schema.value?.toString(),
          validations: widget.schema.validations,
          readOnly: _isReadOnly,
          isRequired: hasRequiredValidation(widget.schema.validations),
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          innerLabel:
              translateIfPresent(widget.schema.innerLabel, localizations),
        );

      case PropertySchemaFormat.mobileNumber:
        return JsonSchemaStringBuilder(
          form: form,
          inputType: TextInputType.number,
          prefixText:
              translateIfPresent(widget.schema.prefixText, localizations),
          suffixText:
              translateIfPresent(widget.schema.suffixText, localizations),
          label: translateIfPresent(widget.schema.label, localizations),
          formControlName: widget.formControlName,
          value: widget.schema.value?.toString(),
          validations: widget.schema.validations,
          readOnly: _isReadOnly,
          isRequired: hasRequiredValidation(widget.schema.validations),
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          innerLabel:
              translateIfPresent(widget.schema.innerLabel, localizations),
        );

      default:
        return JsonSchemaStringBuilder(
          form: form,
          prefixText:
              translateIfPresent(widget.schema.prefixText, localizations),
          suffixText:
              translateIfPresent(widget.schema.suffixText, localizations),
          label: translateIfPresent(widget.schema.label, localizations),
          formControlName: widget.formControlName,
          value: widget.schema.value?.toString(),
          validations: widget.schema.validations,
          readOnly: _isReadOnly,
          isRequired: hasRequiredValidation(widget.schema.validations),
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          innerLabel:
              translateIfPresent(widget.schema.innerLabel, localizations),
        );
    }
  }

  /// Handle `integer` type formats
  Widget _buildIntegerType(FormGroup form) {
    final format = widget.schema.format;

    switch (format) {
      case PropertySchemaFormat.text:
        return JsonSchemaNumberBuilder(
          form: form,
          prefixText:
              translateIfPresent(widget.schema.prefixText, localizations),
          suffixText:
              translateIfPresent(widget.schema.suffixText, localizations),
          label: translateIfPresent(widget.schema.label, localizations),
          formControlName: widget.formControlName,
          inputType: TextInputType.number,
          readOnly: _isReadOnly,
          validations: widget.schema.validations,
          isRequired: hasRequiredValidation(widget.schema.validations),
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          innerLabel:
              translateIfPresent(widget.schema.innerLabel, localizations),
        );

      case PropertySchemaFormat.mobileNumber:
        return JsonSchemaNumberBuilder(
          form: form,
          label: translateIfPresent(widget.schema.label, localizations),
          formControlName: widget.formControlName,
          inputType: TextInputType.number,
          readOnly: _isReadOnly,
          validations: widget.schema.validations,
          isRequired: hasRequiredValidation(widget.schema.validations),
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          innerLabel:
              translateIfPresent(widget.schema.innerLabel, localizations),
        );

      case PropertySchemaFormat.date:
        return JsonSchemaDatePickerBuilder(
          readOnly: _isReadOnly,
          isRequired: hasRequiredValidation(widget.schema.validations),
          label: translateIfPresent(widget.schema.label, localizations),
          form: form,
          formControlName: widget.formControlName,
          start: _safeTimestamp("startDate") != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  _safeTimestamp("startDate")!)
              : null,
          end: _safeTimestamp("endDate") != null
              ? DateTime.fromMillisecondsSinceEpoch(_safeTimestamp("endDate")!)
              : null,
          validations: widget.schema.validations,
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
        );

      case PropertySchemaFormat.numeric:
        return JsonSchemaIntegerBuilder(
          form: form,
          value: parseIntValue(widget.schema.value) ?? 0,
          formControlName: widget.formControlName,
          label: translateIfPresent(widget.schema.label, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          minValue: minFromValidations(widget.schema.validations ?? []),
          maxValue: maxFromValidations(widget.schema.validations ?? []),
          relativeMinValue:
              relativeMinFromValidations(widget.schema.validations ?? [], form),
          relativeMaxValue:
              relativeMaxFromValidations(widget.schema.validations ?? [], form),
          readOnly: _isReadOnly,
          validations: widget.schema.validations,
          isRequired: hasRequiredValidation(widget.schema.validations),
          helpText: translateIfPresent(widget.schema.helpText, localizations),
        );

      case PropertySchemaFormat.custom:
        return _buildCustomComponent() ?? const SizedBox.shrink();

      default:
        return JsonSchemaNumberBuilder(
          form: form,
          label: translateIfPresent(widget.schema.label, localizations),
          formControlName: widget.formControlName,
          readOnly: _isReadOnly,
          validations: widget.schema.validations,
          helpText: translateIfPresent(widget.schema.helpText, localizations),
        );
    }
  }

  /// Handle `boolean` type
  Widget _buildBooleanType(FormGroup form) {
    final format = widget.schema.format;

    switch (format) {
      case PropertySchemaFormat.checkbox:
        return JsonSchemaCheckboxBuilder(
          form: form,
          formControlName: widget.formControlName,
          label: translateIfPresent(widget.schema.label, localizations),
          validations: widget.schema.validations,
          readOnly: widget.schema.readOnly ?? false,
          isRequired: hasRequiredValidation(widget.schema.validations),
        );

      case PropertySchemaFormat.radio:
        return JsonSchemaRadioBuilder(
          form: form,
          isBoolean: true,
          formControlName: widget.formControlName,
          validations: widget.schema.validations,
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          label: translateIfPresent(widget.schema.label, localizations),
          enums: widget.schema.enums ?? [],
          readOnly: widget.schema.readOnly ?? false,
        );

      case PropertySchemaFormat.custom:
        return _buildCustomComponent() ?? const SizedBox.shrink();

      default:
        return JsonSchemaStringBuilder(
          form: form,
          label: translateIfPresent(widget.schema.label, localizations),
          formControlName: widget.formControlName,
          value: widget.schema.value as String?,
          readOnly: _isReadOnly,
          validations: widget.schema.validations,
          helpText: translateIfPresent(widget.schema.helpText, localizations),
          tooltipText: translateIfPresent(widget.schema.tooltip, localizations),
          innerLabel:
              translateIfPresent(widget.schema.innerLabel, localizations),
        );
    }
  }

  /// Handle `object` type
  Widget _buildObjectType(FormGroup form) {
    final entries = widget.schema.properties?.entries.toList() ?? [];

    // Check if any field has visibility conditions
    final hasVisibilityConditions = entries.any(
      (entry) => entry.value.visibilityCondition != null,
    );

    // If there are visibility conditions, wrap in ReactiveFormConsumer
    // to ensure fields rebuild when dependent values change
    if (hasVisibilityConditions) {
      return ReactiveFormConsumer(
        builder: (context, formGroup, child) {
          return _buildObjectFields(formGroup, entries);
        },
      );
    }

    return _buildObjectFields(form, entries);
  }

  /// Build the object fields column
  Widget _buildObjectFields(
      FormGroup form, List<MapEntry<String, PropertySchema>> entries) {
    final visibleEntries = entries.where((entry) {
      final subSchema = entry.value;
      if (subSchema.displayOnly == true) return false;
      return !_shouldHideField(form, subSchema, entry.key);
    }).toList();

    // Hidden latLng fields are not shown, but must still mount so they can
    // silently capture the device location into the form control (consumed by
    // transformers, e.g. to save lat/long on a Task during the delivery flow).
    final silentLatLngEntries = entries.where((entry) {
      final subSchema = entry.value;
      return subSchema.format == PropertySchemaFormat.latLng &&
          form.contains(entry.key) &&
          _shouldHideField(form, subSchema, entry.key);
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final mapEntry = entry.value;

          final subSchema = mapEntry.value;
          final subName = mapEntry.key;

          final field = JsonFormBuilder(
            pageName: widget.pageName,
            currentSchemaKey: widget.currentSchemaKey,
            formControlName: subName,
            schema: subSchema,
            components: widget.components,
            navigationParams: widget.navigationParams,
          );

          final isLast = index == visibleEntries.length - 1;

          return isLast
              ? field
              : Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: field,
                );
        }),
        ...silentLatLngEntries.map(
          (entry) => Offstage(
            offstage: true,
            child: JsonSchemaLatLngBuilder(
              formControlName: entry.key,
              form: form,
              silent: true,
            ),
          ),
        ),
      ],
    );
  }

  /// Handle `custom` format
  Widget? _buildCustomComponent() {
    if (widget.components == null || widget.components!.isEmpty) return null;
    for (var component in widget.components!) {
      if (component.containsKey(widget.formControlName)) {
        return component[widget.formControlName]!;
      }
    }
    return null;
  }
}
