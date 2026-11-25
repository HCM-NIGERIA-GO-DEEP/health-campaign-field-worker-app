import 'package:digit_flow_builder/utils/descendant_project_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> dp(String id, String boundary,
        {String type = 'Distribution Point',
        bool? isDeleted,
        List<dynamic>? descendants}) =>
    {
      'id': id,
      'address': {'boundary': boundary, 'boundaryType': type},
      if (isDeleted != null) 'isDeleted': isDeleted,
      if (descendants != null) 'descendants': descendants,
    };

Map<String, dynamic> response(List<dynamic> descendants) => {
      'Project': [
        {'id': 'hf-project', 'descendants': descendants},
      ],
    };

void main() {
  // ProjectBloc skips the descendants search for a project mapped at this
  // level: its own id already is the DP project.
  group('isDistributionPointBoundaryType', () {
    test('is true for the DP level, trimmed and case-insensitive', () {
      expect(isDistributionPointBoundaryType('Distribution Point'), isTrue);
      expect(isDistributionPointBoundaryType(' distribution POINT '), isTrue);
    });

    test('is false for other levels, empty and null', () {
      expect(isDistributionPointBoundaryType('Health Facility'), isFalse);
      expect(isDistributionPointBoundaryType('Community'), isFalse);
      expect(isDistributionPointBoundaryType(''), isFalse);
      expect(isDistributionPointBoundaryType(null), isFalse);
    });
  });

  group('boundaryProjectIdsFromSearchResponse', () {
    test('reads flat descendants', () {
      expect(
        boundaryProjectIdsFromSearchResponse(response([
          dp('p-a', 'DP_A'),
          dp('p-b', 'DP_B'),
        ])),
        {'DP_A': 'p-a', 'DP_B': 'p-b'},
      );
    });

    test('walks nested descendants', () {
      expect(
        boundaryProjectIdsFromSearchResponse(response([
          dp('p-hf', 'HF_1', type: 'Health Facility', descendants: [
            dp('p-a', 'DP_A', descendants: [dp('p-c', 'DP_C')]),
          ]),
        ])),
        {'DP_A': 'p-a', 'DP_C': 'p-c'},
      );
    });

    test('matches the boundary type trimmed and case-insensitively', () {
      expect(
        boundaryProjectIdsFromSearchResponse(
            response([dp('p-a', 'DP_A', type: '  distribution POINT ')])),
        {'DP_A': 'p-a'},
      );
    });

    test('skips descendants that are not Distribution Points', () {
      expect(
        boundaryProjectIdsFromSearchResponse(response([
          dp('p-hf', 'HF_1', type: 'Health Facility'),
          dp('p-c', 'COMM_1', type: 'Community'),
          dp('p-a', 'DP_A'),
        ])),
        {'DP_A': 'p-a'},
      );
    });

    test('skips deleted descendants', () {
      expect(
        boundaryProjectIdsFromSearchResponse(response([
          dp('p-a', 'DP_A', isDeleted: true),
          dp('p-b', 'DP_B', isDeleted: false),
        ])),
        {'DP_B': 'p-b'},
      );
    });

    test('skips descendants without an id or boundary', () {
      expect(
        boundaryProjectIdsFromSearchResponse(response([
          {
            'address': {'boundary': 'DP_A', 'boundaryType': 'Distribution Point'}
          },
          {
            'id': 'p-b',
            'address': {'boundaryType': 'Distribution Point'}
          },
          {'id': 'p-c'},
          dp('', 'DP_D'),
          dp('p-e', ''),
          dp('p-f', 'DP_F'),
        ])),
        {'DP_F': 'p-f'},
      );
    });

    test('returns {} for null or malformed input and never throws', () {
      for (final input in <dynamic>[
        null,
        'not a map',
        42,
        <String, dynamic>{},
        {'Project': null},
        {'Project': 'oops'},
        {
          'Project': [null, 1, 'x']
        },
        {
          'Project': [
            {'descendants': 'oops'}
          ]
        },
        {
          'Project': [
            {
              'descendants': [
                null,
                1,
                {'id': 7, 'address': 'x'},
                {'id': 'p', 'address': {'boundary': 3, 'boundaryType': null}},
              ]
            }
          ]
        },
      ]) {
        expect(boundaryProjectIdsFromSearchResponse(input), isEmpty,
            reason: '$input');
      }
    });

    test('keeps what it could parse next to malformed entries', () {
      expect(
        boundaryProjectIdsFromSearchResponse({
          'Project': [
            null,
            {
              'descendants': [
                'junk',
                dp('p-a', 'DP_A', descendants: ['junk']),
              ]
            },
          ],
        }),
        {'DP_A': 'p-a'},
      );
    });
  });

  group('beneficiaryProjectIdFor', () {
    const map = {'DP_A': 'p-a', 'DP_B': 'p-b'};

    test('the boundary code itself matches', () {
      expect(
        beneficiaryProjectIdFor(
            boundaryCode: 'DP_A', boundaryProjectIds: map),
        'p-a',
      );
    });

    test('an ancestor in the materialized path matches', () {
      expect(
        beneficiaryProjectIdFor(
          materializedPath: 'LR.DIST.HF_1.DP_B.COMM_1',
          boundaryCode: 'COMM_1',
          boundaryProjectIds: map,
        ),
        'p-b',
      );
    });

    test('the DP nearest to the leaf wins', () {
      expect(
        beneficiaryProjectIdFor(
          materializedPath: 'LR.DP_A.DP_B.COMM_1',
          boundaryCode: 'COMM_1',
          boundaryProjectIds: map,
        ),
        'p-b',
      );
    });

    test('the boundary code wins over its ancestors', () {
      expect(
        beneficiaryProjectIdFor(
          materializedPath: 'LR.DP_A.DP_B',
          boundaryCode: 'DP_B',
          boundaryProjectIds: map,
        ),
        'p-b',
      );
    });

    test('no match returns null', () {
      expect(
        beneficiaryProjectIdFor(
          materializedPath: 'LR.DIST.HF_1.DP_C.COMM_1',
          boundaryCode: 'COMM_1',
          boundaryProjectIds: map,
        ),
        isNull,
      );
    });

    test('a null path and null code return null', () {
      expect(beneficiaryProjectIdFor(boundaryProjectIds: map), isNull);
      expect(
        beneficiaryProjectIdFor(
            boundaryCode: 'COMM_1', boundaryProjectIds: map),
        isNull,
      );
    });

    test('an empty map returns null', () {
      expect(
        beneficiaryProjectIdFor(
          materializedPath: 'LR.DP_A.COMM_1',
          boundaryCode: 'DP_A',
          boundaryProjectIds: const {},
        ),
        isNull,
      );
    });
  });
}
