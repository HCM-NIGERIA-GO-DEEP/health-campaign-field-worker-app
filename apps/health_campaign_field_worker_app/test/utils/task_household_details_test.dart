import 'dart:convert';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/task_household_details.dart';

class _Unknown {}

class _Throws {
  @override
  String toString() => throw StateError('unreadable');
}

/// The head gender and the member list the delivery task carries for the
/// distribution report (one ITN task per household).
void main() {
  setUpAll(initializeMappers);

  Map<String, dynamic> individual({
    String id = 'ind-1',
    String? given = 'Ama',
    String? family = 'Doe',
    Object? gender = 'FEMALE',
    String? dob = '10/05/2023',
    List<Map<String, dynamic>>? identifiers,
  }) =>
      {
        'clientReferenceId': id,
        'name': {'givenName': given, 'familyName': family},
        'gender': gender,
        'dateOfBirth': dob,
        'identifiers': identifiers ??
            [
              {'identifierType': 'DEFAULT', 'identifierId': 'uuid-placeholder'},
              {'identifierType': 'UNIQUE_BENEFICIARY_ID', 'identifierId': 'B-1'},
            ],
      };

  Map<String, dynamic> row(Map<String, dynamic>? ind, {Object? head = false}) =>
      {
        'member': [
          {
            'isHeadOfHousehold': head,
            'individualClientReferenceId': ind?['clientReferenceId'],
          },
        ],
        'individual': ind == null ? const [] : [ind],
      };

  List<dynamic> decode(String? text) => jsonDecode(text!) as List<dynamic>;

  group('individualGender', () {
    test('reads the code from a map', () {
      expect(individualGender(individual(gender: 'MALE')), 'MALE');
    });

    test('reads an enum value and a real IndividualModel', () {
      expect(individualGender({'gender': Gender.female}), 'FEMALE');
      expect(
        individualGender(
          IndividualModel(clientReferenceId: 'h', gender: Gender.male),
        ),
        'MALE',
      );
    });

    test('takes the first entry of a list', () {
      expect(individualGender([individual(gender: 'OTHER')]), 'OTHER');
    });

    test('is null when there is no gender or nothing readable', () {
      expect(individualGender(null), isNull);
      expect(individualGender(individual(gender: null)), isNull);
      expect(individualGender(individual(gender: ' ')), isNull);
      expect(individualGender(_Unknown()), isNull);
      expect(individualGender(42), isNull);
    });
  });

  group('householdMembersForTask', () {
    test('lists every member that is not the head', () {
      final members = decode(householdMembersForTask([
        row(individual(id: 'head', given: 'Head'), head: true),
        row(individual()),
        row(individual(
          id: 'ind-2',
          given: 'Kofi',
          gender: 'MALE',
          dob: '01/01/2022',
          identifiers: [
            {'identifierType': 'UNIQUE_BENEFICIARY_ID', 'identifierId': 'B-2'},
          ],
        )),
      ]));

      expect(members, [
        {
          'individualClientReferenceId': 'ind-1',
          'name': 'Ama Doe',
          'gender': 'FEMALE',
          'dateOfBirth': '10/05/2023',
          'beneficiaryId': 'B-1',
        },
        {
          'individualClientReferenceId': 'ind-2',
          'name': 'Kofi Doe',
          'gender': 'MALE',
          'dateOfBirth': '01/01/2022',
          'beneficiaryId': 'B-2',
        },
      ]);
    });

    test('reads the head flag as true, "true" or 1', () {
      for (final head in [true, 'true', 'TRUE', 1]) {
        expect(householdMembersForTask([row(individual(), head: head)]), isNull,
            reason: 'head flag $head');
      }
    });

    test('a household with only its head, or no rows, gives null', () {
      expect(householdMembersForTask([row(individual(), head: true)]), isNull);
      expect(householdMembersForTask(const []), isNull);
      expect(householdMembersForTask(null), isNull);
      expect(householdMembersForTask('members'), isNull);
    });

    test('leaves out keys that have no value', () {
      final members = decode(householdMembersForTask([
        row(individual(
          family: null,
          gender: null,
          dob: ' ',
          identifiers: [
            {'identifierType': 'DEFAULT', 'identifierId': 'uuid-placeholder'},
          ],
        )),
      ]));

      expect(members, [
        {'individualClientReferenceId': 'ind-1', 'name': 'Ama'},
      ]);
    });

    test('a member whose individual is missing keeps its reference id', () {
      final members = decode(householdMembersForTask([
        {
          'member': [
            {'isHeadOfHousehold': false, 'individualClientReferenceId': 'x'},
          ],
          'individual': const [],
        },
      ]));

      expect(members, [
        {'individualClientReferenceId': 'x'},
      ]);
    });

    test('skips null and unreadable rows and keeps the others', () {
      final members = decode(householdMembersForTask([
        null,
        _Unknown(),
        42,
        {'member': null, 'individual': null},
        row(individual()),
      ]));

      expect(members, hasLength(1));
      expect((members.single as Map)['beneficiaryId'], 'B-1');
    });

    test('a row that throws while being read does not lose the others', () {
      final members = decode(householdMembersForTask([
        row(individual(id: 'bad')..['dateOfBirth'] = _Throws()),
        row(individual()),
      ]));

      expect(members, hasLength(1));
      expect((members.single as Map)['individualClientReferenceId'], 'ind-1');
    });

    test('accepts a single row map', () {
      expect(decode(householdMembersForTask(row(individual()))), hasLength(1));
    });

    test('reads real models', () {
      final child = IndividualModel(
        clientReferenceId: 'ind-9',
        name: NameModel(
          individualClientReferenceId: 'ind-9',
          givenName: 'Esi',
          familyName: 'Doe',
        ),
        gender: Gender.female,
        dateOfBirth: '02/03/2024',
        identifiers: [
          IdentifierModel(
            clientReferenceId: 'i',
            individualClientReferenceId: 'ind-9',
            identifierType: 'UNIQUE_BENEFICIARY_ID',
            identifierId: 'B-9',
          ),
        ],
      );
      final member = HouseholdMemberModel(
        clientReferenceId: 'm',
        isHeadOfHousehold: false,
        individualClientReferenceId: 'ind-9',
      );

      final members = decode(householdMembersForTask([
        {
          'member': [member],
          'individual': [child],
        },
      ]));

      expect(members, [
        {
          'individualClientReferenceId': 'ind-9',
          'name': 'Esi Doe',
          'gender': 'FEMALE',
          'dateOfBirth': '02/03/2024',
          'beneficiaryId': 'B-9',
        },
      ]);
    });
  });
}
