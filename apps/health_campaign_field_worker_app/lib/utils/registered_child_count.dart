// The rows are maps or models, read by field name; a missing field is caught.
// ignore_for_file: avoid_dynamic_calls

/// Number of registered household members that are not the head.
///
/// [members] is the `members` relation of the household wrapper: a list of
/// rows, each holding its HouseholdMember under `member` (also read:
/// `members`, `householdMember`, or the row itself), as maps or as models.
///
/// Two rules read this one count, so they cannot disagree:
///   * fn:isUnder5CountMismatch - householdOverview keeps Back/Close disabled
///     while it differs from the household's children count;
///   * fn:registeredChildCount - on a household edit the children count may
///     not go below it.
///
/// Never throws: both callers run inside flow `fn:` rules, where a throw
/// blanks the whole screen. A row it cannot read counts as a child, the same
/// as a row without a head flag.
int registeredChildCount(dynamic members) {
  final List<dynamic> rows;
  if (members is List) {
    rows = members;
  } else if (members is Map) {
    rows = [members];
  } else {
    return 0;
  }

  var count = 0;
  for (final row in rows) {
    if (row == null) continue;
    if (!_isHead(_memberOf(row))) count++;
  }
  return count;
}

dynamic _memberOf(dynamic row) {
  if (row is Map) {
    return row['member'] ?? row['members'] ?? row['householdMember'] ?? row;
  }
  for (final read in <dynamic Function()>[
    () => row.member,
    () => row.members,
    () => row.householdMember,
  ]) {
    try {
      final value = read();
      if (value != null) return value;
    } catch (_) {
      // Not a field of this row; try the next name.
    }
  }
  return row;
}

bool _isHead(dynamic member) {
  if (member is List) {
    return member.any((m) => m != null && _headFlag(m));
  }
  return member != null && _headFlag(member);
}

bool _headFlag(dynamic member) {
  dynamic value;
  if (member is Map) {
    value = member['isHeadOfHousehold'];
  } else {
    try {
      value = member.isHeadOfHousehold;
    } catch (_) {
      return false;
    }
  }
  return value == true ||
      value == 1 ||
      value?.toString().toLowerCase() == 'true';
}
