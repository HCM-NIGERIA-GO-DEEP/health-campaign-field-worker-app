// Pure rules for giving pool IDs (unique_id_pool rows) to individuals at save
// time. No Flutter, no repositories: UpdateIdentifierStatusExecutor does the
// I/O and calls these functions with the user's free rows.
import 'package:digit_data_model/data_model.dart';

const uniqueBeneficiaryIdType = 'UNIQUE_BENEFICIARY_ID';
const defaultIdentifierType = 'DEFAULT';
const poolStatusUnassigned = 'UN_ASSIGNED';
const poolStatusAssigned = 'ASSIGNED';

enum PoolIdOutcome {
  /// The individual already pointed to a free row of the user.
  kept,

  /// The identifier was DEFAULT, missing, or pointed to a used, foreign,
  /// unknown or already-given row; it now points to the oldest free row.
  reassigned,

  /// No free row was left. The individual is unchanged (UUID stays).
  exhausted,
}

class PoolIdAssignment {
  const PoolIdAssignment({
    required this.original,
    required this.individual,
    required this.outcome,
    required this.reason,
    this.row,
    this.replaced,
  });

  /// The individual as it came in.
  final IndividualModel original;

  /// The individual to save (the same object unless [outcome] is reassigned).
  final IndividualModel individual;
  final PoolIdOutcome outcome;
  final String reason;

  /// The pool row to mark ASSIGNED; null when [outcome] is exhausted.
  final UniqueIdPoolModel? row;

  /// The identifier whose type and value were replaced; null when kept,
  /// exhausted, or when a new identifier was added.
  final IdentifierModel? replaced;
}

class PoolIdAssignmentResult {
  const PoolIdAssignmentResult(this.assignments);

  final List<PoolIdAssignment> assignments;

  bool get anyExhausted =>
      assignments.any((a) => a.outcome == PoolIdOutcome.exhausted);
}

/// Oldest first by audit createdTime (missing time counts as 0), then by id,
/// so the order is stable.
List<UniqueIdPoolModel> sortOldestFirst(Iterable<UniqueIdPoolModel> rows) {
  final list = rows.toList();
  list.sort((a, b) {
    final byTime = (a.auditDetails?.createdTime ?? 0)
        .compareTo(b.auditDetails?.createdTime ?? 0);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
  return list;
}

/// Gives each individual one pool row, in list order. A row is never given
/// twice. Rows that are not UN_ASSIGNED or not owned by [userUuid] are
/// ignored, even if the caller passes them.
PoolIdAssignmentResult assignPoolIds({
  required List<IndividualModel> individuals,
  required List<UniqueIdPoolModel> unassignedRows,
  required String userUuid,
  required String Function() newClientReferenceId,
  String identifierType = uniqueBeneficiaryIdType,
}) {
  final available = sortOldestFirst(unassignedRows.where(
      (r) => r.status == poolStatusUnassigned && r.userUuid == userUuid));
  final given = <String>{};
  final assignments = <PoolIdAssignment>[];

  UniqueIdPoolModel? freeRow(String id) {
    for (final r in available) {
      if (r.id == id && !given.contains(r.id)) return r;
    }
    return null;
  }

  UniqueIdPoolModel? oldestFreeRow() {
    for (final r in available) {
      if (!given.contains(r.id)) return r;
    }
    return null;
  }

  for (final individual in individuals) {
    final identifiers = individual.identifiers ?? const <IdentifierModel>[];

    String? currentId;
    for (final i in identifiers) {
      final id = i.identifierId;
      if (i.identifierType == identifierType && id != null && id.isNotEmpty) {
        currentId = id;
        break;
      }
    }

    if (currentId != null) {
      final row = freeRow(currentId);
      if (row != null) {
        given.add(row.id);
        assignments.add(PoolIdAssignment(
          original: individual,
          individual: individual,
          outcome: PoolIdOutcome.kept,
          reason: 'points to a free row of this user',
          row: row,
        ));
        continue;
      }
    }

    final why = currentId == null
        ? 'had no pool ID'
        : given.contains(currentId)
            ? 'pool ID already given in this save'
            : 'pool ID is used, unknown, or another user\'s';

    final row = oldestFreeRow();
    if (row == null) {
      assignments.add(PoolIdAssignment(
        original: individual,
        individual: individual,
        outcome: PoolIdOutcome.exhausted,
        reason: '$why; no free pool ID left',
      ));
      continue;
    }
    given.add(row.id);

    // Replace the pool-type identifier, else the DEFAULT one, else add one.
    var target = identifiers.indexWhere((i) => i.identifierType == identifierType);
    if (target < 0) {
      target = identifiers
          .indexWhere((i) => i.identifierType == defaultIdentifierType);
    }

    final List<IdentifierModel> patched;
    IdentifierModel? replaced;
    if (target >= 0) {
      replaced = identifiers[target];
      patched = [...identifiers];
      patched[target] = replaced.copyWith(
        identifierType: identifierType,
        identifierId: row.id,
      );
    } else {
      patched = [
        ...identifiers,
        IdentifierModel(
          clientReferenceId: newClientReferenceId(),
          individualClientReferenceId: individual.clientReferenceId,
          identifierType: identifierType,
          identifierId: row.id,
          tenantId: individual.tenantId,
        ),
      ];
    }

    assignments.add(PoolIdAssignment(
      original: individual,
      individual: individual.copyWith(identifiers: patched),
      outcome: PoolIdOutcome.reassigned,
      reason: why,
      row: row,
      replaced: replaced,
    ));
  }

  return PoolIdAssignmentResult(assignments);
}

/// Turns the individual's pool-type identifier into DEFAULT/[uuid], keeping
/// the identifier object's other fields. Used when the pool row could not be
/// marked ASSIGNED: the row stays free, so the individual must not keep its ID
/// (another individual would get it later). Returns null when the individual
/// has no pool-type identifier with a value.
IndividualModel? withoutPoolId(
  IndividualModel individual, {
  required String identifierType,
  required String uuid,
}) {
  final identifiers = individual.identifiers;
  if (identifiers == null) return null;
  final index = identifiers.indexWhere((i) =>
      i.identifierType == identifierType &&
      (i.identifierId?.isNotEmpty ?? false));
  if (index < 0) return null;
  final patched = [...identifiers];
  patched[index] = identifiers[index]
      .copyWith(identifierType: defaultIdentifierType, identifierId: uuid);
  return individual.copyWith(identifiers: patched);
}

/// The row as UPDATE_IDENTIFIER_STATUS stores it after giving it out.
UniqueIdPoolModel markPoolRowAssigned(
  UniqueIdPoolModel row, {
  required String userUuid,
  required int nowMillis,
}) {
  final audit = row.clientAuditDetails != null
      ? row.clientAuditDetails!.copyWith(
          lastModifiedBy: userUuid,
          lastModifiedTime: nowMillis,
        )
      : ClientAuditDetails(
          createdBy: row.auditDetails?.createdBy ?? userUuid,
          createdTime: row.auditDetails?.createdTime ?? nowMillis,
          lastModifiedBy: userUuid,
          lastModifiedTime: nowMillis,
        );
  return row.copyWith(status: poolStatusAssigned, clientAuditDetails: audit);
}

/// Returns a copy of [formData] where every `identifiers` value equal to
/// "[fromType], [fromId]" becomes "[toType], [toId]". The form stores the
/// hidden identifiers field in that format (form_builder_helper.dart), and the
/// acknowledgement screen shows it. Returns [formData] when nothing matches.
Map<String, dynamic>? replaceIdentifierInFormData(
  Map<String, dynamic>? formData, {
  required String fromType,
  required String fromId,
  required String toType,
  required String toId,
}) {
  if (formData == null) return null;
  var changed = false;

  bool matches(dynamic value) {
    if (value is! String) return false;
    final parts = value.split(',').map((p) => p.trim()).toList();
    return parts.length == 2 && parts[0] == fromType && parts[1] == fromId;
  }

  // Copies keep their map type, so later `as Map<String, dynamic>` casts in
  // other executors still work.
  dynamic walk(dynamic node) {
    if (node is! Map) return node;
    final Map out =
        node is Map<String, dynamic> ? <String, dynamic>{} : <dynamic, dynamic>{};
    node.forEach((key, value) {
      if (key == 'identifiers' && matches(value)) {
        changed = true;
        out[key] = '$toType, $toId';
      } else {
        out[key] = walk(value);
      }
    });
    return out;
  }

  final result = walk(formData) as Map<String, dynamic>;
  return changed ? result : formData;
}
