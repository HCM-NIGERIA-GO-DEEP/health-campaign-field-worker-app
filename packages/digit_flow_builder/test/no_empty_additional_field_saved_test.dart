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

/// Amit, 2026-11-26: "do not submit empty value or null in additionalFields".
///
/// CREATE_EVENT and UPDATE_EVENT are the two actions every config-driven form
/// saves through, so they are where the rule is enforced: whatever built the
/// record (a mapping, the fallback merge, a `modify` entry, a record that
/// already held an empty field), nothing with a null or empty additional
/// field value reaches a repository.
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

  HouseholdModel household(List<AdditionalField> fields) => HouseholdModel(
        clientReferenceId: 'household',
        tenantId: 'lb',
        rowVersion: 1,
        memberCount: 2,
        additionalFields: HouseholdAdditionalFields(version: 1, fields: fields),
      );

  Map<String, dynamic> fieldsOf(EntityModel model) => {
        for (final f
            in ((model.toMap()['additionalFields'] as Map?)?['fields'] as List?) ??
                const [])
          (f as Map)['key'] as String: f['value'],
      };

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

  group('CREATE_EVENT', () {
    testWidgets('saves no additional field with a null or empty value',
        (tester) async {
      final context = await pumpContext(tester);

      await tester.runAsync(() async {
        await CrudExecutor().execute(action('CREATE_EVENT'), context, {
          'entities': [
            household(const [
              AdditionalField('caregiverConsent', 'FALSE'),
              AdditionalField('nameOfIndividual', null),
              AdditionalField('familyname', ''),
              AdditionalField('comments', '  '),
              AdditionalField('childrenCount', 0),
            ]),
          ],
        });
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      final saved = service.created.single as HouseholdModel;
      expect(fieldsOf(saved), {'caregiverConsent': 'FALSE', 'childrenCount': 0});
      expect(saved.clientReferenceId, 'household');
      expect(saved.memberCount, 2);
    });

    testWidgets('passes a record without empty fields through untouched',
        (tester) async {
      final context = await pumpContext(tester);
      final record = household(const [AdditionalField('caregiverConsent', 'TRUE')]);

      await tester.runAsync(() async {
        await CrudExecutor()
            .execute(action('CREATE_EVENT'), context, {'entities': [record]});
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(service.created.single, same(record));
    });
  });

  group('CREATE_EVENT keeps the rest of the record exactly as it was', () {
    const audit = AuditDetails(
      createdBy: 'user',
      createdTime: 1700000000000,
      lastModifiedBy: 'user',
      lastModifiedTime: 1700000000001,
    );
    final clientAudit = ClientAuditDetails(
      createdBy: 'user',
      createdTime: 1700000000000,
      lastModifiedBy: 'user',
      lastModifiedTime: 1700000000001,
    );

    final records = <String, EntityModel>{
      'IndividualModel': IndividualModel(
        clientReferenceId: 'individual',
        id: 'server-individual',
        tenantId: 'lb',
        rowVersion: 3,
        dateOfBirth: '01/01/2024',
        mobileNumber: '0111111111',
        gender: Gender.female,
        name: NameModel(
          individualClientReferenceId: 'individual',
          givenName: 'Given',
          familyName: 'Family',
        ),
        identifiers: [
          IdentifierModel(
            clientReferenceId: 'identifier',
            individualClientReferenceId: 'individual',
            identifierType: 'UNIQUE_BENEFICIARY_ID',
            identifierId: 'TOKEN',
          ),
        ],
        address: [
          AddressModel(
            relatedClientReferenceId: 'individual',
            latitude: 6.3,
            longitude: -10.8,
          ),
        ],
        auditDetails: audit,
        clientAuditDetails: clientAudit,
        additionalFields: IndividualAdditionalFields(version: 1, fields: const [
          AdditionalField('height', 90),
          AdditionalField('weight', null),
          AdditionalField('isPregnant', ''),
        ]),
      ),
      'TaskModel': TaskModel(
        clientReferenceId: 'task',
        id: 'server-task',
        tenantId: 'lb',
        rowVersion: 2,
        projectId: 'project',
        projectBeneficiaryClientReferenceId: 'beneficiary',
        status: 'ADMINISTRATION_SUCCESS',
        createdDate: 1700000000000,
        resources: [
          TaskResourceModel(
            clientReferenceId: 'resource',
            taskclientReferenceId: 'task',
            productVariantId: 'variant',
            quantity: '2',
            isDelivered: true,
          ),
        ],
        auditDetails: audit,
        clientAuditDetails: clientAudit,
        additionalFields: TaskAdditionalFields(version: 1, fields: const [
          AdditionalField('cycleIndex', '1'),
          AdditionalField('deliveryComment', ''),
          AdditionalField('scanResource', null),
        ]),
      ),
      'ProjectBeneficiaryModel': ProjectBeneficiaryModel(
        clientReferenceId: 'beneficiary',
        id: 'server-beneficiary',
        tenantId: 'lb',
        rowVersion: 1,
        projectId: 'project',
        beneficiaryClientReferenceId: 'household',
        dateOfRegistration: 1700000000000,
        tag: 'TAG',
        auditDetails: audit,
        clientAuditDetails: clientAudit,
        additionalFields:
            ProjectBeneficiaryAdditionalFields(version: 1, fields: const [
          AdditionalField('kept', 'value'),
          AdditionalField('dropped', '  '),
        ]),
      ),
      'HouseholdMemberModel': HouseholdMemberModel(
        clientReferenceId: 'member',
        tenantId: 'lb',
        rowVersion: 1,
        householdClientReferenceId: 'household',
        individualClientReferenceId: 'individual',
        isHeadOfHousehold: true,
        auditDetails: audit,
        clientAuditDetails: clientAudit,
        additionalFields:
            HouseholdMemberAdditionalFields(version: 1, fields: const [
          AdditionalField('name', 'Given Family'),
          AdditionalField('gender', null),
        ]),
      ),
      'StockModel': StockModel(
        clientReferenceId: 'stock',
        tenantId: 'lb',
        rowVersion: 1,
        productVariantId: 'variant',
        quantity: '50',
        transactionType: 'DISPATCHED',
        senderId: 'sender',
        senderType: 'WAREHOUSE',
        receiverId: 'receiver',
        receiverType: 'STAFF',
        dateOfEntry: 1700000000000,
        auditDetails: audit,
        clientAuditDetails: clientAudit,
        additionalFields: StockAdditionalFields(version: 1, fields: const [
          AdditionalField('mrnNumber', 'MRN-1'),
          AdditionalField('wayBillNumber', null),
          AdditionalField('vehicleNumber', ''),
        ]),
      ),
    };

    for (final entry in records.entries) {
      testWidgets(entry.key, (tester) async {
        final context = await pumpContext(tester);
        final record = entry.value;

        await tester.runAsync(() async {
          await CrudExecutor()
              .execute(action('CREATE_EVENT'), context, {'entities': [record]});
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });

        final saved = service.created.single;
        expect(saved.runtimeType, record.runtimeType);
        final expected = Map.of(fieldsOf(record))
          ..removeWhere(
              (_, v) => v == null || (v is String && v.trim().isEmpty));
        expect(expected.length, lessThan(fieldsOf(record).length));
        expect(fieldsOf(saved), expected);

        // Everything except the dropped fields is byte-for-byte the same.
        Map<String, dynamic> withoutFields(EntityModel model) =>
            Map<String, dynamic>.from(model.toMap())
              ..['additionalFields'] = {
                ...?(model.toMap()['additionalFields'] as Map?),
                'fields': null,
              };
        expect(withoutFields(saved), withoutFields(record));
      });
    }
  });

  group('UPDATE_EVENT', () {
    const modifyFamilyName = {
      'entity': 'HouseholdModel',
      'modify': [
        {
          'key': 'HouseholdModel.additionalFields.fields.familyName',
          'value': '{{formData.householdDetails.familyname}}',
        },
      ],
    };

    HouseholdModel stored() => household(const [
          AdditionalField('caregiverConsent', 'TRUE'),
          AdditionalField('familyName', 'Stored family'),
        ]);

    Future<void> update(
      WidgetTester tester,
      Map<String, dynamic> properties, {
      required EntityModel entity,
      Map<String, dynamic> formData = const {},
    }) async {
      final context = await pumpContext(tester);
      await tester.runAsync(() => UpdateExecutor().execute(
            action('UPDATE_EVENT', properties),
            context,
            {
              'entities': [entity],
              'existingModels': [stored()],
              'formData': formData,
            },
          ));
    }

    testWidgets('a modify entry writes the value the form gives',
        (tester) async {
      await update(tester, modifyFamilyName, entity: stored(), formData: {
        'householdDetails': {'familyname': 'New family'},
      });

      expect(fieldsOf(service.updated.single),
          {'caregiverConsent': 'TRUE', 'familyName': 'New family'});
    });

    testWidgets('a modify entry the form has no value for keeps the stored one',
        (tester) async {
      await update(tester, modifyFamilyName, entity: stored(), formData: {
        'householdDetails': {'familyname': null},
      });

      // Nothing else changed, so nothing is saved. Before, the template
      // text itself was written as the family name.
      expect(service.updated, isEmpty);
    });

    testWidgets(
        'the reopen shape: the status changes and the name the form does not '
        'give stays', (tester) async {
      await update(tester, {
        'entity': 'HouseholdModel',
        'modify': [
          {'key': 'HouseholdModel.memberCount', 'value': 5},
          {
            'key': 'HouseholdModel.additionalFields.fields.familyName',
            'value': '{{formData.householdDetails.familyname}}',
          },
        ],
      }, entity: stored(), formData: {
        'householdDetails': {'familyname': null},
      });

      final saved = service.updated.single as HouseholdModel;
      expect(saved.memberCount, 5);
      expect(fieldsOf(saved),
          {'caregiverConsent': 'TRUE', 'familyName': 'Stored family'});
    });

    testWidgets('an empty modify value keeps the stored one', (tester) async {
      await update(tester, {
        'entity': 'HouseholdModel',
        'modify': [
          {
            'key': 'HouseholdModel.additionalFields.fields.familyName',
            'value': '  ',
          },
          {
            'key': 'HouseholdModel.additionalFields.fields.memberCount',
            'value': '3',
          },
        ],
      }, entity: stored());

      expect(fieldsOf(service.updated.single), {
        'caregiverConsent': 'TRUE',
        'familyName': 'Stored family',
        'memberCount': '3',
      });
    });

    testWidgets('a record that already holds an empty field is saved clean',
        (tester) async {
      await update(
        tester,
        const {'entity': 'HouseholdModel'},
        entity: household(const [
          AdditionalField('caregiverConsent', null),
          AdditionalField('familyName', 'Edited family'),
          AdditionalField('comments', ''),
          // What QA's screenshot showed on a consent "No" household.
          AdditionalField('nameOfIndividual', '{{navigation.firstName}}'),
        ]),
      );

      final fields = fieldsOf(service.updated.single);
      expect(fields, {'familyName': 'Edited family'});
    });
  });
}
