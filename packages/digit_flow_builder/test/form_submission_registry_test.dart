import 'dart:convert';

import 'package:digit_flow_builder/blocs/form_submission_registry.dart';
import 'package:digit_forms_engine/blocs/forms/forms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editing a retained form submits only the current values', () async {
    final bloc = FormsBloc();
    final registry = FormSubmissionRegistry()..initialize(bloc);
    addTearDown(() async {
      registry.dispose();
      await bloc.close();
    });
    final submittedNames = <String>[];
    registry.register(
      schemaKey: 'closed',
      instanceId: 'review',
      handler: (data) async {
        submittedNames.add(data['details']['headName'] as String);
      },
    );
    Future<void> dispatch(FormsEvent event) async {
      final next = bloc.stream.first;
      bloc.add(event);
      await next;
      await Future<void>.delayed(Duration.zero);
    }

    await dispatch(FormsEvent.load(schemas: [
      jsonEncode({
        'name': 'closed',
        'version': 1,
        'pages': {
          'details': {
            'type': 'object',
            'properties': {
              'headName': {'type': 'string', 'value': 'Try first'}
            }
          }
        }
      })
    ]));
    await dispatch(const FormsEvent.submit(schemaKey: 'closed', isEdit: false));
    expect(submittedNames, ['Try first']);

    for (final name in ['try second', 'try third']) {
      final schema = bloc.state.cachedSchemas['closed']!;
      final page = schema.pages['details']!;
      final previousCount = submittedNames.length;
      await dispatch(FormsEvent.update(
        schemaKey: 'closed',
        schema: schema.copyWith(pages: {
          'details': page.copyWith(properties: {
            'headName': page.properties!['headName']!.copyWith(value: name),
          }),
        }),
      ));
      expect(submittedNames.length, previousCount,
          reason: 'Updating cached values must not replay the last submission');
      await dispatch(const FormsEvent.submit(schemaKey: 'closed', isEdit: false));
      expect(submittedNames.last, name);
    }

    expect(submittedNames, ['Try first', 'try second', 'try third']);
  });
  test('multi-page submit preserves values and edit mode across clear/reload',
      () async {
    final bloc = FormsBloc();
    final registry = FormSubmissionRegistry()..initialize(bloc);
    addTearDown(() async {
      registry.dispose();
      await bloc.close();
    });
    final submissions = <Map<String, dynamic>>[];
    registry.register(
      schemaKey: 'multiPage',
      instanceId: 'normal',
      handler: (data) async => submissions.add(data),
    );
    Future<void> dispatch(FormsEvent event) async {
      final next = bloc.stream.first;
      bloc.add(event);
      await next;
      await Future<void>.delayed(Duration.zero);
    }
    final definition = jsonEncode({
      'name': 'multiPage',
      'version': 1,
      'pages': {
        'details': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'value': 'Original'}
          }
        },
        'products': {
          'type': 'object',
          'properties': {
            'quantity_item_0': {'type': 'number', 'value': 5}
          }
        }
      }
    });
    await dispatch(FormsEvent.load(schemas: [definition]));
    final schema = bloc.state.cachedSchemas['multiPage']!;
    await dispatch(FormsEvent.update(
      schemaKey: 'multiPage',
      schema: schema.copyWith(pages: {
        ...schema.pages,
        'products': schema.pages['products']!.copyWith(properties: {
          'quantity_item_0': schema.pages['products']!
              .properties!['quantity_item_0']!.copyWith(value: 8)
        })
      }),
    ));
    expect(submissions, isEmpty);
    await dispatch(const FormsEvent.submit(schemaKey: 'multiPage', isEdit: true));
    expect((bloc.state as FormsSubmittedState).isEdit, isTrue);
    expect(submissions.single['details']['name'], 'Original');
    expect(submissions.single['products']['quantity_item_0'], 8);

    await dispatch(const FormsEvent.clearPage(
        schemaKey: 'multiPage', pageKey: 'products'));
    expect(submissions.length, 1);
    expect(bloc.state.cachedSchemas['multiPage']!.pages['details']!
        .properties!['name']!.value, 'Original');

    await dispatch(const FormsEvent.clearForm(schemaKey: 'multiPage'));
    await dispatch(const FormsEvent.submit(schemaKey: 'multiPage'));
    expect((bloc.state as FormsSubmittedState).isEdit, isFalse);
    expect(submissions.last['products']['quantity_item_0'], 5);
    await dispatch(FormsEvent.load(schemas: [definition]));
    expect(submissions.length, 2,
        reason: 'Reloading after submit must not replay the submission');
  });

}
