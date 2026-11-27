import 'package:digit_crud_bloc/bloc/crud_bloc.dart';
import 'package:digit_crud_bloc/service/crud_service.dart';
import 'package:digit_crud_bloc/utils/utils.dart';
import 'package:digit_data_converter/utils/utils.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/crud_executor.dart';
import 'package:digit_flow_builder/data/digit_crud_service.dart';
import 'package:digit_flow_builder/data/digit_data_converter.dart';
import 'package:digit_flow_builder/utils/household_head_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what CREATE_EVENT and UPDATE_EVENT hand to the repositories.
class _Capture extends CrudService {
  final created = <EntityModel>[];
  final updated = <EntityModel>[];

  @override
  bool get isInitialized => true;

  @override
  Future<void> createEntities(List<EntityModel> entities) async =>
      created.addAll(entities);

  @override
  Future<void> updateEntities(List<EntityModel> entities) async =>
      updated.addAll(entities);
}

/// Liberia CR (2026-11-27): the household record must carry its head's
/// details, and an edit must keep them right.
///
/// CREATE_EVENT and UPDATE_EVENT copy them from the head's Individual in the
/// same save: headName, headMobileNumber, headGender,
/// headIndividualClientReferenceId. They are read from the record that is
/// being saved, so they cannot disagree with it, whichever form or config
/// built the records.
void main() {
  late _Capture service;

  setUpAll(() {
    initializeMappers();
    DataConverterSingleton()
        .setData(dynamicEntityModelListener: EntityModelJsonMapper());
  });

  setUp(() {
    service = _Capture();
    CrudBlocSingleton().setData(
      crudService: service,
      dynamicEntityModelListener: EntityModelMapMapper(),
    );
  });

  HouseholdModel household([List<AdditionalField> fields = const []]) =>
      HouseholdModel(
        clientReferenceId: 'household',
        id: 'server-household',
        tenantId: 'lr',
        rowVersion: 1,
        memberCount: 3,
        additionalFields: HouseholdAdditionalFields(version: 1, fields: fields),
      );

  IndividualModel individual({
    String ref = 'head',
    String given = 'Given',
    String? family = 'Family',
    String? mobile = '0770000001',
    Gender? gender = Gender.female,
  }) =>
      IndividualModel(
        clientReferenceId: ref,
        id: 'server-$ref',
        tenantId: 'lr',
        rowVersion: 1,
        mobileNumber: mobile,
        gender: gender,
        name: NameModel(
          individualClientReferenceId: ref,
          givenName: given,
          familyName: family,
        ),
      );

  HouseholdMemberModel member({
    String individualRef = 'head',
    String householdRef = 'household',
    required bool head,
  }) =>
      HouseholdMemberModel(
        clientReferenceId: 'member-$individualRef',
        tenantId: 'lr',
        rowVersion: 1,
        householdClientReferenceId: householdRef,
        individualClientReferenceId: individualRef,
        isHeadOfHousehold: head,
      );

  Map<String, dynamic> fieldsOf(EntityModel model) => {
        for (final f
            in ((model.toMap()['additionalFields'] as Map?)?['fields'] as List?) ??
                const [])
          (f as Map)['key'] as String: f['value'],
      };

  List<String> keysOf(EntityModel model) => [
        for (final f
            in ((model.toMap()['additionalFields'] as Map?)?['fields'] as List?) ??
                const [])
          (f as Map)['key'] as String,
      ];

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext context;
    final bloc = await tester.runAsync(() async => CrudBloc(service: service));
    addTearDown(bloc!.close);
    await tester.pumpWidget(BlocProvider<CrudBloc>.value(
      value: bloc,
      child: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      }),
    ));
    return context;
  }

  ActionConfig action(String type, [Map<String, dynamic> properties = const {}]) =>
      ActionConfig.fromJson({'actionType': type, 'properties': properties});

  Future<List<EntityModel>> create(
    WidgetTester tester,
    List<EntityModel> entities, [
    Map<String, dynamic> properties = const {},
  ]) async {
    final context = await pumpContext(tester);
    await tester.runAsync(() async {
      await CrudExecutor().execute(
          action('CREATE_EVENT', properties), context, {'entities': entities});
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    return service.created;
  }

  Future<List<EntityModel>> update(
    WidgetTester tester,
    List<EntityModel> entities, {
    List<EntityModel> existing = const [],
    Map<String, dynamic> properties = const {},
    Map<String, dynamic> extra = const {},
  }) async {
    final context = await pumpContext(tester);
    await tester.runAsync(() => UpdateExecutor().execute(
          action('UPDATE_EVENT', properties),
          context,
          {'entities': entities, 'existingModels': existing, ...extra},
        ));
    return service.updated;
  }

  const headDetails = {
    'headName': 'Given Family',
    'headMobileNumber': '0770000001',
    'headGender': 'FEMALE',
    'headIndividualClientReferenceId': 'head',
  };

  group('CREATE_EVENT', () {
    testWidgets('a new household carries its head\'s details', (tester) async {
      final saved = await create(tester, [
        household(const [AdditionalField('childrenCount', 2)]),
        individual(),
        member(head: true),
      ]);

      final record = saved.whereType<HouseholdModel>().single;
      expect(fieldsOf(record), {'childrenCount': 2, ...headDetails});
      expect(record.clientReferenceId, 'household');
      expect(record.id, 'server-household');
      expect(record.memberCount, 3);
      expect(saved, hasLength(3), reason: 'the other records are still saved');
      expect(saved.whereType<IndividualModel>().single.mobileNumber,
          '0770000001');
    });

    testWidgets('a head without phone or gender gets no empty field',
        (tester) async {
      final saved = await create(tester, [
        household(),
        individual(mobile: null, gender: null, family: null),
      ]);

      expect(fieldsOf(saved.whereType<HouseholdModel>().single), {
        'headName': 'Given',
        'headIndividualClientReferenceId': 'head',
      });
    });

    testWidgets('a household saved without its head is left as it is',
        (tester) async {
      final record = household(const [AdditionalField('childrenCount', 2)]);
      final saved = await create(tester, [record]);

      expect(saved.single, same(record));
    });

    testWidgets('a member who is not the head is not copied', (tester) async {
      final saved = await create(tester, [
        household(const [AdditionalField('childrenCount', 2)]),
        individual(ref: 'child'),
        member(individualRef: 'child', head: false),
      ]);

      expect(fieldsOf(saved.whereType<HouseholdModel>().single),
          {'childrenCount': 2});
    });

    testWidgets('another person\'s member record does not stop the copy',
        (tester) async {
      final saved = await create(tester, [
        household(),
        individual(),
        member(head: true),
        member(individualRef: 'child', head: false),
      ]);

      expect(fieldsOf(saved.whereType<HouseholdModel>().single), headDetails);
    });

    testWidgets('the head of another household is not copied', (tester) async {
      final saved = await create(tester, [
        household(),
        individual(),
        member(householdRef: 'another-household', head: true),
      ]);

      expect(fieldsOf(saved.whereType<HouseholdModel>().single), isEmpty);
    });

    testWidgets('two individuals in one save: nothing is guessed',
        (tester) async {
      final saved = await create(tester, [
        household(),
        individual(),
        individual(ref: 'second'),
      ]);

      expect(fieldsOf(saved.whereType<HouseholdModel>().single), isEmpty);
    });

    testWidgets('an individual left out by the entity filter is not used',
        (tester) async {
      final saved = await create(
        tester,
        [household(), individual()],
        {'entity': 'HouseholdModel'},
      );

      expect(fieldsOf(saved.single), isEmpty);
    });
  });

  test('a batch that is already right is returned as it is', () {
    final batch = <EntityModel>[
      household(const [
        AdditionalField('headName', 'Given Family'),
        AdditionalField('headMobileNumber', '0770000001'),
        AdditionalField('headGender', 'FEMALE'),
        AdditionalField('headIndividualClientReferenceId', 'head'),
      ]),
      individual(),
    ];

    expect(withHouseholdHeadDetails(batch), same(batch));
  });

  group('UPDATE_EVENT', () {
    testWidgets('an edit of the head replaces the old details on the household',
        (tester) async {
      final stored = household(const [
        AdditionalField('headName', 'Old Name'),
        AdditionalField('childrenCount', 2),
        AdditionalField('headMobileNumber', '0770000009'),
        AdditionalField('headGender', 'MALE'),
        AdditionalField('headIndividualClientReferenceId', 'head'),
      ]);
      final saved = await update(
        tester,
        [stored, individual()],
        existing: [stored, individual(given: 'Old', family: 'Name')],
      );

      final record = saved.whereType<HouseholdModel>().single;
      expect(fieldsOf(record), {'childrenCount': 2, ...headDetails});
      expect(keysOf(record), [
        'headName',
        'childrenCount',
        'headMobileNumber',
        'headGender',
        'headIndividualClientReferenceId',
      ], reason: 'a changed value stays where it was');
      expect(record.id, 'server-household');
    });

    testWidgets('a household registered before this change gets the details',
        (tester) async {
      final stored = household(const [AdditionalField('childrenCount', 2)]);
      final saved = await update(
        tester,
        [stored, individual()],
        existing: [stored, individual()],
      );

      expect(fieldsOf(saved.whereType<HouseholdModel>().single),
          {'childrenCount': 2, ...headDetails});
    });

    testWidgets('a phone removed from the head is removed from the household',
        (tester) async {
      final stored = household(const [
        AdditionalField('headName', 'Given Family'),
        AdditionalField('headMobileNumber', '0770000001'),
        AdditionalField('headGender', 'FEMALE'),
        AdditionalField('headIndividualClientReferenceId', 'head'),
      ]);
      final saved = await update(
        tester,
        [stored, individual(mobile: null)],
        existing: [stored, individual()],
      );

      expect(fieldsOf(saved.whereType<HouseholdModel>().single), {
        'headName': 'Given Family',
        'headGender': 'FEMALE',
        'headIndividualClientReferenceId': 'head',
      });
    });

    testWidgets('nothing changed: the household is not written again',
        (tester) async {
      final stored = household(const [
        AdditionalField('childrenCount', 2),
        AdditionalField('headName', 'Given Family'),
        AdditionalField('headMobileNumber', '0770000001'),
        AdditionalField('headGender', 'FEMALE'),
        AdditionalField('headIndividualClientReferenceId', 'head'),
      ]);
      final saved = await update(
        tester,
        [stored, individual()],
        existing: [stored, individual()],
      );

      expect(saved, isEmpty);
    });

    testWidgets('the details follow a `modify` on the individual',
        (tester) async {
      final stored = household();
      final saved = await update(
        tester,
        [stored, individual()],
        existing: [stored, individual()],
        properties: {
          'modify': [
            {'key': 'IndividualModel.mobileNumber', 'value': '0880000002'},
          ],
        },
      );

      expect(saved.whereType<IndividualModel>().single.mobileNumber,
          '0880000002');
      expect(
          fieldsOf(saved.whereType<HouseholdModel>().single)['headMobileNumber'],
          '0880000002');
    });

    testWidgets('editing a child leaves the household alone', (tester) async {
      final stored = household(const [
        AdditionalField('headName', 'Given Family'),
        AdditionalField('headIndividualClientReferenceId', 'head'),
      ]);
      final child = individual(ref: 'child', given: 'New child');
      final saved = await update(
        tester,
        [stored, child, member(individualRef: 'child', head: false)],
        existing: [
          stored,
          individual(ref: 'child', given: 'Child'),
          member(individualRef: 'child', head: false),
        ],
      );

      expect(saved.whereType<HouseholdModel>(), isEmpty);
      expect(saved.whereType<IndividualModel>().single.name?.givenName,
          'New child');
    });

    testWidgets('a household updated without its head keeps what it has',
        (tester) async {
      final stored = household(const [
        AdditionalField('headName', 'Given Family'),
        AdditionalField('childrenCount', 2),
      ]);
      final saved = await update(
        tester,
        [stored, individual(given: 'Other')],
        existing: [stored],
        properties: {
          'entity': 'HouseholdModel',
          'modify': [
            {
              'key': 'HouseholdModel.additionalFields.fields.childrenCount',
              'value': 3,
            },
          ],
        },
      );

      expect(fieldsOf(saved.single),
          {'headName': 'Given Family', 'childrenCount': 3});
    });
  });
}
