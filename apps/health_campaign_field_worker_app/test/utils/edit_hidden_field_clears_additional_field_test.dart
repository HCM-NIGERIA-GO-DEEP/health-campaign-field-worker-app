// QA (2026-11-13): a child registered above 11 months with a height was
// edited to a DOB under 12 months. The Height field disappeared, but the old
// height was still stored in the Project Task.
//
// Cause: hiding a field resets its control to null
// (VisibilityManager.toggleControlVisibility), so the edit form submits
// `beneficiaryDetails.height: null`. On edit, FormEntityMapper's
// additionalFields merge skipped null form values and kept every existing
// key, so the Individual kept `height`. Each delivery screen then copies
// `item.individual.0.additionalFields.fields.height` into the new task.
//
// Fix: the forms engine records which fields the user saw and their own
// edit then hid (visibilityCondition), and the edit merge drops a stored
// key only for those fields when their submitted value is null. Every
// other case (no list, a visible field left empty, a field hidden from the
// start, a page never opened) keeps today's behaviour; the tests below
// pin both sides.
//
// These tests run the real `individualRegistration` mapping through
// updateEntitiesFromForm, the same call the transformer makes in edit mode.

import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as data_model_mappers;
// ignore: implementation_imports
import 'package:digit_data_converter/src/transformer_service.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/data/transformer_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _configName = 'individualRegistration';
const _heightHidden = {'beneficiaryDetails.height'};

IndividualModel _child({Map<String, dynamic>? additionalFields}) =>
    IndividualModel(
      clientReferenceId: 'ind-1',
      tenantId: 'ng',
      name: NameModel(givenName: 'Amina', familyName: 'Bello'),
      dateOfBirth: '01/03/2025',
      gender: Gender.female,
      additionalFields: additionalFields == null
          ? null
          : IndividualAdditionalFields(
              version: 1,
              fields: [
                for (final e in additionalFields.entries)
                  AdditionalField(e.key, e.value),
              ],
            ),
    );

/// The ADD_MEMBER edit form as FormsBloc submits it: every non-hidden field
/// of the page, blank strings already turned into null.
Map<String, dynamic> _editForm({
  required String dobPicker,
  required dynamic height,
  bool includeHeight = true,
}) =>
    {
      'beneficiaryDetails': {
        'nameOfIndividual': 'Amina',
        'familyname': 'Bello',
        'dobPicker': dobPicker,
        'gender': 'FEMALE',
        if (includeHeight) 'height': height,
        'phone': null,
      },
    };

/// Mirrors TransformerExecutor's edit branch: only the models being edited,
/// with the config's fallback model.
IndividualModel _saveEdit(
  IndividualModel existing,
  Map<String, dynamic> form, {
  Set<String>? hidden,
}) {
  final config = jsonConfig[_configName] as Map<String, dynamic>;
  final models = Map<String, dynamic>.from(config['models'] as Map)
    ..removeWhere((key, _) => key != 'IndividualModel');

  final mapper = FormEntityMapper(config: jsonConfig);
  final result = hidden == null
      ? mapper.updateEntitiesFromForm(
          existingModels: [existing],
          formValues: form,
          modelsConfig: models,
          context: const {'cycleIndexStamp': '3'},
          fallbackFormDataString: config['fallbackModel'] as String?,
        )
      : mapper.updateEntitiesFromForm(
          existingModels: [existing],
          formValues: form,
          modelsConfig: models,
          context: const {'cycleIndexStamp': '3'},
          fallbackFormDataString: config['fallbackModel'] as String?,
          hiddenFormPaths: hidden,
        );
  return result.whereType<IndividualModel>().single;
}

Map<String, dynamic>? _fields(IndividualModel individual) {
  final fields = individual.additionalFields?.fields;
  if (fields == null) return null;
  return {for (final f in fields) f.key: f.value};
}

void main() {
  setUpAll(() {
    data_model_mappers.initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  group('a field the user saw and then hid', () {
    test('drops its stored value from the individual', () {
      final saved = _saveEdit(
        _child(additionalFields: {'height': '85', 'cycleIndexStamp': '1'}),
        _editForm(dobPicker: '01/03/2026', height: null),
        hidden: _heightHidden,
      );

      expect(_fields(saved), {'cycleIndexStamp': '1'});
    });

    test('changes nothing else on the individual', () {
      final existing = _child(additionalFields: {
        'height': '85',
        'weight': '9',
        'cycleIndexStamp': '1',
      });
      final form = _editForm(dobPicker: '01/03/2026', height: null);

      final before = _saveEdit(existing, form).toMap()
        ..remove('additionalFields');
      final after = _saveEdit(existing, form, hidden: _heightHidden).toMap()
        ..remove('additionalFields');

      expect(const DeepCollectionEquality().equals(after, before), isTrue,
          reason: 'before: $before\nafter:  $after');
    });

    test('keeps the keys the form does not own', () {
      final saved = _saveEdit(
        _child(additionalFields: {
          'height': '85',
          'weight': '9',
          'cycleIndexStamp': '1',
        }),
        _editForm(dobPicker: '01/03/2026', height: null),
        hidden: _heightHidden,
      );

      // weight is mapped but not on the ADD_MEMBER form; cycleIndexStamp comes
      // from context and keeps its first value on edit.
      expect(_fields(saved), {'weight': '9', 'cycleIndexStamp': '1'});
    });

    test('is saved as before when it still carries a value', () {
      final saved = _saveEdit(
        _child(additionalFields: {'height': '85', 'cycleIndexStamp': '1'}),
        _editForm(dobPicker: '01/03/2026', height: '92'),
        hidden: _heightHidden,
      );

      expect(_fields(saved), {'height': '92', 'cycleIndexStamp': '1'});
    });

    test('that was never stored saves exactly as before', () {
      final form = _editForm(dobPicker: '01/03/2026', height: null);

      final before = _saveEdit(_child(), form).toMap();
      final after = _saveEdit(_child(), form, hidden: _heightHidden).toMap();

      expect(const DeepCollectionEquality().equals(after, before), isTrue,
          reason: 'before: $before\nafter:  $after');
    });

    test('is left alone when the form does not carry it', () {
      final saved = _saveEdit(
        _child(additionalFields: {'height': '85', 'cycleIndexStamp': '1'}),
        _editForm(dobPicker: '01/03/2024', height: null, includeHeight: false),
        hidden: _heightHidden,
      );

      expect(_fields(saved), {'height': '85', 'cycleIndexStamp': '1'});
    });
  });

  group('unchanged behaviour', () {
    test('a null field that was not hidden keeps its stored value', () {
      // A visible optional field left empty, or a field on a page the user
      // never opened: both arrive as null without being in the hidden list.
      final saved = _saveEdit(
        _child(additionalFields: {'height': '85', 'cycleIndexStamp': '1'}),
        _editForm(dobPicker: '01/03/2026', height: null),
        hidden: const {},
      );

      expect(_fields(saved), {'height': '85', 'cycleIndexStamp': '1'});
    });

    test('a caller that passes no hidden list keeps the stored value', () {
      final saved = _saveEdit(
        _child(additionalFields: {'height': '85', 'cycleIndexStamp': '1'}),
        _editForm(dobPicker: '01/03/2026', height: null),
      );

      expect(_fields(saved), {'height': '85', 'cycleIndexStamp': '1'});
    });

    test('a visible height replaces the old value', () {
      final saved = _saveEdit(
        _child(additionalFields: {'height': '85', 'cycleIndexStamp': '1'}),
        _editForm(dobPicker: '01/03/2024', height: '92'),
      );

      expect(_fields(saved), {'height': '92', 'cycleIndexStamp': '1'});
    });
  });
}
