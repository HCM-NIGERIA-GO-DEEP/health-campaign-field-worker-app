library json_forms;

import 'package:digit_forms_engine/utils/utils.dart';
import 'package:digit_forms_engine/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'helper/form_builder_helper.dart';
import 'models/property_schema/property_schema.dart';

class JsonForms extends StatelessWidget {
  final PropertySchema propertySchema;
  final List<Map<String, Widget>>? childrens;
  final Map<String, dynamic>? defaultValues;
  final String pageName;
  final String currentSchemaKey;
  final Map<String, dynamic>? navigationParams;

  const JsonForms({
    super.key,
    required this.propertySchema,
    this.childrens,
    this.defaultValues,
    required this.pageName,
    required this.currentSchemaKey,
    this.navigationParams,
  });

  static Map<String, AbstractControl<dynamic>> getFormControls(
    PropertySchema schema, {
    String? defaultLatlng,
    Map<String, dynamic>? defaultValues,
    String? schemaKey,
    Map<String, dynamic>? navigationParams,
  }) {
    assert(schema.properties != null);

    final Map<String, AbstractControl<dynamic>> controls = {
      for (final entry in schema.properties!.entries)
        if (entry.value.displayOnly != true &&
            (!isHidden(entry.value) || entry.value.includeInForm == true))
          entry.key: buildFormControl(
            entry.key,
            entry.value,
            schema,
            defaultLatlng: defaultLatlng,
            defaultValues: defaultValues,
            navigationParams: navigationParams,
            schemaKey: schemaKey,
          ),
    };

    return controls;
  }

  static Map<String, dynamic> getFormValues(
    FormGroup form,
    PropertySchema schema,
  ) {
    final values = schema.properties!.entries
        .where((entry) => (!isHidden(entry.value) ||
            entry.value.includeInForm == true)) // Skip hidden fields
        .map((e) => _getParsedValues(form, e.key, e.value))
        .whereType<MapEntry<String, dynamic>>()
        .toList();

    final result = Map.fromEntries(values);

    // Additionally, collect any form controls with entity suffixes (e.g., fieldName_item_0)
    // These are created by MultiEntityTabView and need to be preserved for the transformer
    for (final controlKey in form.controls.keys) {
      if (controlKey.contains('_item_')) {
        result[controlKey] = form.control(controlKey).value;
      }
    }

    return result;
  }

  static MapEntry<String, dynamic>? _getParsedValues(
    FormGroup form,
    String name,
    PropertySchema schema,
  ) {
    if (schema.type == PropertySchemaType.object) {
      final results = schema.properties!.entries.map((e) {
        return _getParsedValues(form, e.key, e.value);
      });
      return MapEntry(
        name,
        Map.fromEntries(results.whereType<MapEntry<String, dynamic>>()),
      );
    } else {
      // Skip if control doesn't exist (hidden field without includeInForm: true,
      // or renamed in MultiEntityTabView)
      if (!form.contains(name)) {
        return null;
      }

      final value = form.control(name).value;
      // Normally a null control value is omitted so forms_render.dart's
      // post-submit rebuild (schema.properties?.map: keeps the OLD prop
      // when `values` doesn't contain the key) leaves an edited-but-
      // untouched field's existing value alone - the right behavior for
      // most optional fields. Household head-name fields are the
      // exception: their schema default is a "{{navigation.firstName}}"
      // style template (see buildFormControl's resolveInitialValue), and
      // when that template never resolves (e.g. reopening a closed
      // household with no prior head individual) the control's value is
      // correctly nulled out by the required validator, but omitting the
      // key here would leave that literal, unresolved template sitting in
      // the schema and submitted as if it were a real name. Only these
      // head-name fields need the key to always be reported:
      // nameOfIndividual/familyname on householdDetails, and
      // firstName/lastName on caregiverConsent (whose defaults are
      // "{{navigation.firstName}}"/"{{navigation.lastName}}"). The consent
      // pair matters now that those fields are optional for a declined
      // consent - leaving them blank is a legitimate outcome, so the null
      // has to overwrite the template rather than be dropped.
      const alwaysReportKeys = {
        'nameOfIndividual',
        'familyname',
        'firstName',
        'lastName',
      };
      if (value == null && !alwaysReportKeys.contains(name)) return null;
      return MapEntry(name, value);
    }
  }

  @override
  Widget build(BuildContext context) => JsonFormBuilder(
        schema: propertySchema,
        formControlName: '/',
        components: childrens,
        pageName: pageName,
        currentSchemaKey: currentSchemaKey,
        navigationParams: navigationParams,
      );
}
