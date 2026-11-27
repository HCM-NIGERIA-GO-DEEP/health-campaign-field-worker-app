/// True only when [record] names a creator and it is not [userUuid].
///
/// The server rejects an Individual update from anyone but its creator
/// (INVALID_USER_ID on the beneficiary id), so Edit is disabled for other
/// users. An unknown creator or user returns false: nothing new is blocked.
///
/// [record] is a model, its map, or a list holding one (`item.individual`).
bool createdByAnotherUser(dynamic record, String? userUuid) {
  try {
    if (userUuid == null || userUuid.isEmpty) return false;
    if (record is List) {
      if (record.isEmpty) return false;
      record = record.first;
    }
    if (record == null) return false;
    final Map map = record is Map ? record : (record as dynamic).toMap() as Map;
    for (final key in const ['auditDetails', 'clientAuditDetails']) {
      final audit = map[key];
      final createdBy = audit is Map ? audit['createdBy']?.toString() : null;
      if (createdBy != null && createdBy.isNotEmpty) {
        return createdBy != userUuid;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}
