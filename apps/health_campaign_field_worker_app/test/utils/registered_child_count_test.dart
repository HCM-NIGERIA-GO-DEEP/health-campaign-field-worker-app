import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/registered_child_count.dart';

class _Member {
  _Member(this.isHeadOfHousehold);
  final Object? isHeadOfHousehold;
}

class _Row {
  _Row(this.member);
  final Object? member;
}

class _Unknown {}

/// `registeredChildCount` counts the household members that are not the head.
/// The overview's Back/Close rule (fn:isUnder5CountMismatch) and the children
/// count floor on household edit both use it, so they can never disagree.
void main() {
  Map<String, dynamic> row({required Object? head}) => {
        'member': [
          {'isHeadOfHousehold': head},
        ],
        'individual': const [{}],
      };

  test('counts every member row that is not the head', () {
    expect(
      registeredChildCount([row(head: true), row(head: false), row(head: false)]),
      2,
    );
  });

  test('a household with only its head has no registered children', () {
    expect(registeredChildCount([row(head: true)]), 0);
  });

  test('reads the head flag as true, "true" or 1', () {
    expect(
      registeredChildCount(
          [row(head: 'true'), row(head: 'TRUE'), row(head: 1), row(head: 0)]),
      1,
    );
  });

  test('a missing head flag counts as a child', () {
    expect(registeredChildCount([row(head: null)]), 1);
  });

  test('skips null rows and null entries inside a member list', () {
    expect(
      registeredChildCount([
        null,
        {
          'member': [null, {'isHeadOfHousehold': true}],
        },
        row(head: false),
      ]),
      1,
    );
  });

  test('reads the other relation names and a bare member map', () {
    expect(
      registeredChildCount([
        {
          'members': [
            {'isHeadOfHousehold': true},
          ],
        },
        {
          'householdMember': {'isHeadOfHousehold': false},
        },
        {'isHeadOfHousehold': true},
        {'isHeadOfHousehold': false},
      ]),
      2,
    );
  });

  test('reads model objects as well as maps', () {
    expect(
      registeredChildCount([
        _Row([_Member(true)]),
        _Row([_Member(false)]),
        _Row(_Member(false)),
        _Member(true),
      ]),
      2,
    );
  });

  test('reads a map row that holds member models (the wrapper shape)', () {
    expect(
      registeredChildCount([
        {
          'member': [_Member(true)],
        },
        {
          'member': [_Member(false)],
        },
        {
          'member': [_Member(false)],
        },
      ]),
      2,
    );
  });

  test('a single member map is one row', () {
    expect(registeredChildCount(row(head: false)), 1);
    expect(registeredChildCount(row(head: true)), 0);
  });

  test('anything that is not a list or a map has no members', () {
    expect(registeredChildCount(null), 0);
    expect(registeredChildCount(''), 0);
    expect(registeredChildCount(3), 0);
  });

  test('an unexpected row shape is counted and never throws', () {
    // A throw inside a flow fn: blanks the whole screen.
    expect(registeredChildCount([_Unknown(), _Row(_Unknown())]), 2);
  });
}
