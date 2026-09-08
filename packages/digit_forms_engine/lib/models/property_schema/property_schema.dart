// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'property_schema.freezed.dart';
part 'property_schema.g.dart';

@freezed
class PropertySchema with _$PropertySchema {
  @JsonSerializable(
    explicitToJson: true,
    includeIfNull: false,
  )
  const factory PropertySchema({
    @JsonKey(
      name: 'type',
      unknownEnumValue: PropertySchemaType.string,
    )
    required PropertySchemaType type,
    bool? readOnly,
    bool? displayOnly,
    bool? hidden,
    Map<String, PropertySchema>? properties,
    List<Option>? enums,
    String? schemaCode,
    bool? systemDate,
    bool? charCount,
    @JsonKey(
      name: 'format',
      unknownEnumValue: PropertySchemaFormat.text,
    )
    PropertySchemaFormat? format,
    @JsonKey(fromJson: _stringOrNull) final String? startDate,
    @JsonKey(fromJson: _stringOrNull) final String? endDate,
    @JsonKey(fromJson: _intOrNull) int? minValue,
    @JsonKey(fromJson: _intOrNull) int? maxValue,
    @JsonKey(fromJson: _intOrNull) int? minLength,
    @JsonKey(fromJson: _intOrNull) int? maxLength,
    @JsonKey(fromJson: _intOrNull) int? min,
    @JsonKey(fromJson: _intOrNull) int? max,
    String? helpText,
    String? tooltip,
    String? prefixText,
    String? suffixText,
    String? innerLabel,
    String? label,
    bool? isMultiSelect,
    dynamic value,
    DisplayBehavior? displayBehavior,
    Map<String, dynamic>? conditions,
    double? order,
    String? actionLabel,
    String? description,
    List<ValidationRule>? validations,
    bool? includeInForm,
    bool? includeInSummary,
    @JsonKey(fromJson: _navigateToConfigOrNull) NavigateToConfig? navigateTo,
    @JsonKey(fromJson: _visibilityConditionOrNull)
    VisibilityCondition? visibilityCondition,
    @JsonKey(fromJson: _conditionalNavigateListOrNull)
    List<ConditionalNavigateTo>? conditionalNavigateTo,
    // New: AutoFillCondition list
    @JsonKey(fromJson: _autoFillConditionListOrNull)
    List<AutoFillCondition>? autoFillCondition,
    @JsonKey(fromJson: _showAlertOrNull) ShowAlertPopUp? showAlertPopUp,
    // Secondary action alert popup (e.g., for reject confirmation with comment)
    @JsonKey(fromJson: _showSecondaryAlertOrNull)
    ShowSecondaryAlertPopUp? showSecondaryAlertPopUp,
    // Multi-entity tab configuration
    @JsonKey(fromJson: _multiEntityConfigOrNull)
    MultiEntityConfig? multiEntityConfig,
    // Screenshot protection for this page
    bool? preventScreenCapture,
    // Submit condition for pages - when true, form submits directly instead of navigating to next page
    @JsonKey(fromJson: _visibilityConditionOrNull)
    VisibilityCondition? submitCondition,
    // Secondary action button label (e.g., "Decline" button alongside "Accept")
    String? secondaryActionLabel,
    // Comparison config for scanner fields - enables duplicate detection against historical data
    @JsonKey(fromJson: _comparisonConfigOrNull)
    ComparisonConfig? comparisonConfig,
    // Dedup config for pages - warns about similar existing records on submit
    @JsonKey(fromJson: _dedupCheckOrNull) DedupCheck? dedupCheck,
  }) = _PropertySchema;

  factory PropertySchema.fromJson(Map<String, dynamic> json) =>
      _$PropertySchemaFromJson(json);
}

@freezed
class ValidationRule with _$ValidationRule {
  const factory ValidationRule({
    required String type,
    dynamic value,
    String? message,
  }) = _ValidationRule;

  factory ValidationRule.fromJson(Map<String, dynamic> json) =>
      _$ValidationRuleFromJson(json);
}

@freezed
class Option with _$Option {
  const factory Option({
    required String code,
    required String name,
  }) = _Option;

  factory Option.fromJson(Map<String, dynamic> json) => _$OptionFromJson(json);
}

@freezed
class DisplayBehavior with _$DisplayBehavior {
  const factory DisplayBehavior({
    required FormulaBehavior behavior,
    List<String>? oneOf,
    List<String>? allOf,
  }) = _DisplayBehavior;

  factory DisplayBehavior.fromJson(Map<String, dynamic> json) =>
      _$DisplayBehaviorFromJson(json);
}

@freezed
class NavigateToConfig with _$NavigateToConfig {
  const factory NavigateToConfig({
    required String type, // "template" or "form"
    required String name, // route name or form name
  }) = _NavigateToConfig;

  factory NavigateToConfig.fromJson(Map<String, dynamic> json) =>
      _$NavigateToConfigFromJson(json);
}

@freezed
class VisibilityCondition with _$VisibilityCondition {
  const factory VisibilityCondition({
    required List<VisibilityExpression> expression,
  }) = _VisibilityCondition;

  factory VisibilityCondition.fromJson(Map<String, dynamic> json) =>
      _$VisibilityConditionFromJson(json);
}

@freezed
class VisibilityExpression with _$VisibilityExpression {
  const factory VisibilityExpression({
    required String condition,
  }) = _VisibilityExpression;

  factory VisibilityExpression.fromJson(Map<String, dynamic> json) =>
      _$VisibilityExpressionFromJson(json);
}

@freezed
class ConditionalNavigateTo with _$ConditionalNavigateTo {
  const factory ConditionalNavigateTo({
    required String condition,
    required NavigateToConfig navigateTo,
  }) = _ConditionalNavigateTo;

  factory ConditionalNavigateTo.fromJson(Map<String, dynamic> json) =>
      _$ConditionalNavigateToFromJson(json);
}

@freezed
class AutoFillCondition with _$AutoFillCondition {
  const factory AutoFillCondition({
    required String expression,
    required dynamic value, // could be a string, number, template, etc.
  }) = _AutoFillCondition;

  factory AutoFillCondition.fromJson(Map<String, dynamic> json) =>
      _$AutoFillConditionFromJson(json);
}

@freezed
class ShowAlertPopUp with _$ShowAlertPopUp {
  const factory ShowAlertPopUp({
    required String title,
    String? description, // optional
    required String primaryActionLabel,
    required String secondaryActionLabel,
    List<AlertCondition>? conditions, // optional
  }) = _ShowAlertPopUp;

  factory ShowAlertPopUp.fromJson(Map<String, dynamic> json) =>
      _$ShowAlertPopUpFromJson(json);
}

@freezed
class ShowSecondaryAlertPopUp with _$ShowSecondaryAlertPopUp {
  const factory ShowSecondaryAlertPopUp({
    required String title,
    String? description,
    required String primaryActionLabel,
    required String secondaryActionLabel,
    List<AlertCondition>? conditions,
    // Body fields for form inputs inside the popup (e.g., mandatory comment)
    List<SecondaryAlertBodyField>? body,
  }) = _ShowSecondaryAlertPopUp;

  factory ShowSecondaryAlertPopUp.fromJson(Map<String, dynamic> json) =>
      _$ShowSecondaryAlertPopUpFromJson(json);
}

@freezed
class SecondaryAlertBodyField with _$SecondaryAlertBodyField {
  const factory SecondaryAlertBodyField({
    required String type,
    required String label,
    String? format,
    required String fieldName,
    @Default(false) bool mandatory,
  }) = _SecondaryAlertBodyField;

  factory SecondaryAlertBodyField.fromJson(Map<String, dynamic> json) =>
      _$SecondaryAlertBodyFieldFromJson(json);
}

@freezed
class AlertCondition with _$AlertCondition {
  const factory AlertCondition({
    required String expression, // e.g., condition or "DEFAULT"
    required String value, // e.g., "To Administer"
  }) = _AlertCondition;

  factory AlertCondition.fromJson(Map<String, dynamic> json) =>
      _$AlertConditionFromJson(json);
}

@freezed
class MultiEntityConfig with _$MultiEntityConfig {
  const factory MultiEntityConfig({
    required String sourcePageKey, // Page containing the multi-select field
    required String sourceFieldKey, // Field name of the multi-select
  }) = _MultiEntityConfig;

  factory MultiEntityConfig.fromJson(Map<String, dynamic> json) =>
      _$MultiEntityConfigFromJson(json);
}

@freezed
class ComparisonConfig with _$ComparisonConfig {
  @JsonSerializable(explicitToJson: true, includeIfNull: false)
  const factory ComparisonConfig({
    required String
        model, // table to search (e.g., "stock", "projectBeneficiary")
    required String extractKey, // field to match scanned value against
    @Default('additionalFields')
    String extractFrom, // "additionalFields" or "column"
    @Default([]) List<ComparisonFilter> filters,
    String? errorMessage, // Localization key for the error message
  }) = _ComparisonConfig;

  factory ComparisonConfig.fromJson(Map<String, dynamic> json) =>
      _$ComparisonConfigFromJson(json);
}

@freezed
class ComparisonFilter with _$ComparisonFilter {
  @JsonSerializable(explicitToJson: true, includeIfNull: false)
  const factory ComparisonFilter({
    required String key, // DB column name (e.g., "senderId")
    required String
        value, // default template (e.g., "{{navigation.facilityFromWhich}}")
    @Default('equals') String operation,
    String?
        switchOn, // template for conditional switch (e.g., "{{navigation.stockEntryType}}")
    Map<String, String>?
        cases, // conditional overrides (e.g., {"ISSUED": "{{navigation.facilityToWhich}}"})
  }) = _ComparisonFilter;

  factory ComparisonFilter.fromJson(Map<String, dynamic> json) =>
      _$ComparisonFilterFromJson(json);
}

/// The warning dialog shown when [DedupCheck] finds similar records.
///
/// Mirrors [ShowAlertPopUp] -- title, description and two action labels -- and
/// adds a [body] of flow builder display widgets for the match rows.
///
/// Nested inside [DedupCheck] so one block describes the whole feature, and
/// kept separate from `showAlertPopUp` so a page can carry both a dedup warning
/// and a genuine submit confirmation.
@freezed
class DedupAlertPopUp with _$DedupAlertPopUp {
  const DedupAlertPopUp._();

  @JsonSerializable(explicitToJson: true, includeIfNull: false)
  const factory DedupAlertPopUp({
    /// Localization key for the dialog heading.
    required String title,

    /// Localization key for the body text above [body].
    String? description,

    /// Localization key for the button that continues the submission.
    required String primaryActionLabel,

    /// Localization key for the button that abandons the form.
    required String secondaryActionLabel,

    /// Name of an icon from the shared icon mapping, shown beside the title.
    String? titleIcon,

    /// Flow builder widget JSON for the match rows, typically a `listView`
    /// bound to [matchesKey].
    ///
    /// Left untyped because this package cannot depend on
    /// `digit_flow_builder` -- the dependency runs the other way -- so these
    /// widgets are rendered by whatever registered the dedup check.
    @Default(<dynamic>[]) List<dynamic> body,

    /// Key the match list is published under, for `dataSource` bindings in
    /// [body].
    @Default('dedupMatches') String matchesKey,

    /// Whether each match shows its similarity score. Only consulted by the
    /// built-in dialog -- a [body] decides for itself, e.g. by leaving
    /// `{{item.scoreText}}` out.
    @Default(true) bool showScore,

    /// Localization key for the per-match score, receiving the whole
    /// percentage as `{score}`. Built-in dialog only.
    String? scoreLabel,

    /// Localization key shown in place of a match's beneficiary ID when it has
    /// none. Built-in dialog only.
    String? missingIdLabel,

    /// Both default to false: a duplicate warning should be answered, not
    /// dismissed by accident.
    @Default(false) bool barrierDismissible,
    @Default(false) bool showCloseButton,
  }) = _DedupAlertPopUp;

  factory DedupAlertPopUp.fromJson(Map<String, dynamic> json) =>
      _$DedupAlertPopUpFromJson(json);
}

/// Page-level config that warns the user about existing records similar to the
/// one being registered, before the form is submitted.
///
/// Declared on a page (not a field) because the check scores several fields
/// together. Absent config means no check runs, so the feature stays inert
/// until a page opts in.
@freezed
class DedupCheck with _$DedupCheck {
  const DedupCheck._();

  @JsonSerializable(explicitToJson: true, includeIfNull: false)
  const factory DedupCheck({
    /// Maps a dedup engine attribute to the form field feeding it, e.g.
    /// `{"givenName": "nameOfIndividual", "familyName": "familyname"}`.
    @JsonKey(fromJson: _stringMapOrEmpty) required Map<String, String> fields,

    /// Local model searched for existing records (e.g. "individual").
    @Default('individual') String model,

    /// Scoping filters narrowing the corpus searched for similar records.
    /// At least one is required, since an unfiltered search is rejected.
    @Default(<DedupFilter>[]) List<DedupFilter> filters,

    /// Minimum weighted similarity score (0.0-1.0) for a record to be shown.
    @JsonKey(fromJson: _doubleOrNull) double? matchThreshold,

    /// Most matches listed in the dialog.
    @JsonKey(fromJson: _intOrNull) int? maxResults,

    /// Shortest a mapped field value may be before the check is skipped.
    /// Guards against scoring against a single typed character.
    @JsonKey(fromJson: _intOrNull) int? minFieldLength,

    /// Hard cap on corpus rows loaded into memory for scoring.
    @JsonKey(fromJson: _intOrNull) int? maxCandidates,

    /// Whether the check is skipped while editing an existing record, which
    /// would otherwise match itself.
    @Default(true) bool skipOnEdit,

    /// Page the "back to search" action returns to.
    String? backToSearchPage,

    /// The warning dialog. Absent means the built-in dialog is used with its
    /// own default copy.
    @JsonKey(fromJson: _dedupAlertPopUpOrNull)
    DedupAlertPopUp? dedupAlertPopUp,
  }) = _DedupCheck;

  factory DedupCheck.fromJson(Map<String, dynamic> json) =>
      _$DedupCheckFromJson(json);

  static const double defaultMatchThreshold = 0.85;
  static const int defaultMaxResults = 5;
  static const int defaultMinFieldLength = 2;
  static const int defaultMaxCandidates = 5000;

  double get effectiveMatchThreshold =>
      matchThreshold ?? defaultMatchThreshold;

  int get effectiveMaxResults => maxResults ?? defaultMaxResults;

  int get effectiveMinFieldLength => minFieldLength ?? defaultMinFieldLength;

  int get effectiveMaxCandidates => maxCandidates ?? defaultMaxCandidates;
}

/// A scoping filter on the corpus a [DedupCheck] searches.
///
/// Mirrors the shape of a `SEARCH_EVENT` data entry, so the same
/// `{key, root, value, operation}` config a search screen uses applies here.
@freezed
class DedupFilter with _$DedupFilter {
  @JsonSerializable(explicitToJson: true, includeIfNull: false)
  const factory DedupFilter({
    /// Column filtered on (e.g. "projectId").
    required String key,

    /// Table the column belongs to (e.g. "projectBeneficiary"). Defaults to
    /// the config's own model when omitted.
    String? root,

    /// Value template, e.g. `{{singleton.projectId}}`. A filter whose value
    /// resolves to empty is dropped.
    required String value,

    @Default('equals') String operation,

    /// Template selecting between [cases], e.g. `{{navigation.flowType}}`.
    String? switchOn,

    /// Value templates keyed by the resolved [switchOn] result.
    Map<String, String>? cases,
  }) = _DedupFilter;

  factory DedupFilter.fromJson(Map<String, dynamic> json) =>
      _$DedupFilterFromJson(json);
}

String? _stringOrNull(dynamic value) {
  return value is String ? value : null;
}

int? _intOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

NavigateToConfig? _navigateToConfigOrNull(dynamic value) {
  if (value is Map && value.isEmpty) {
    return null; // Treat {} as null
  }
  if (value is Map<String, dynamic>) {
    return NavigateToConfig.fromJson(value);
  }
  return null;
}

VisibilityCondition? _visibilityConditionOrNull(dynamic value) {
  if (value is Map && value.isEmpty) return null;

  if (value is Map<String, dynamic>) {
    final expr = value['expression'];

    // CASE 1 → expression: { ... }
    if (expr is Map<String, dynamic>) {
      return VisibilityCondition(
        expression: [VisibilityExpression.fromJson(expr)],
      );
    }

    // CASE 2 → expression: [ {...}, {...} ]
    if (expr is List) {
      return VisibilityCondition(
        expression: expr
            .whereType<Map<String, dynamic>>()
            .map((e) => VisibilityExpression.fromJson(e))
            .toList(),
      );
    }

    // FALLBACK
    return null;
  }

  return null;
}

List<ConditionalNavigateTo>? _conditionalNavigateListOrNull(dynamic value) {
  if (value is List) {
    if (value.isEmpty) return null;
    return value
        .whereType<Map<String, dynamic>>() // ignore nulls / wrong types
        .map((map) => ConditionalNavigateTo.fromJson(map))
        .toList();
  }
  return null;
}

// New: AutoFillCondition parser
List<AutoFillCondition>? _autoFillConditionListOrNull(dynamic value) {
  if (value is List) {
    if (value.isEmpty) return null;
    return value
        .whereType<Map<String, dynamic>>()
        .map((map) => AutoFillCondition.fromJson(map))
        .toList();
  }
  return null;
}

ShowAlertPopUp? _showAlertOrNull(dynamic value) {
  if (value is Map && value.isNotEmpty) {
    return ShowAlertPopUp.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

ShowSecondaryAlertPopUp? _showSecondaryAlertOrNull(dynamic value) {
  if (value is Map && value.isNotEmpty) {
    return ShowSecondaryAlertPopUp.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

MultiEntityConfig? _multiEntityConfigOrNull(dynamic value) {
  if (value is Map && value.isNotEmpty) {
    return MultiEntityConfig.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

ComparisonConfig? _comparisonConfigOrNull(dynamic value) {
  if (value is Map && value.isNotEmpty) {
    return ComparisonConfig.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

DedupCheck? _dedupCheckOrNull(dynamic value) {
  if (value is Map && value.isNotEmpty) {
    return DedupCheck.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

DedupAlertPopUp? _dedupAlertPopUpOrNull(dynamic value) {
  if (value is Map && value.isNotEmpty) {
    return DedupAlertPopUp.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Coerces a config map to <String, String>, dropping entries that cannot be
/// read as a pair of strings.
Map<String, String> _stringMapOrEmpty(dynamic value) {
  if (value is! Map) return const {};
  final result = <String, String>{};
  value.forEach((key, entryValue) {
    if (key == null || entryValue == null) return;
    result[key.toString()] = entryValue.toString();
  });
  return result;
}

enum FormulaBehavior { show, hide }

enum PropertySchemaFormat {
  date,
  latLng,
  custom,
  locality,
  select,
  numeric,
  dropdown,
  checkbox,
  radio,
  dob,
  scanner,
  idPopulator,
  mobileNumber,
  textArea,
  text;
}

enum PropertySchemaType { object, string, integer, boolean, dynamic }
