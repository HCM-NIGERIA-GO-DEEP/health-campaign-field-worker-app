final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Display text for one scanned code.
///
/// A delivery team QR holds "userName||userUuid". The field shows only the
/// userName (or the uuid when the name half is empty), because a uuid means
/// nothing to the person scanning. Display only: the form value keeps the
/// whole "userName||userUuid", and the stock functions still save the bare
/// uuid as receiverId/senderId.
///
/// Any other value - no "||", or a second half that is not a uuid - is
/// returned unchanged, so codes from other scanners are never cut.
String teamCodeLabel(String raw) {
  final separator = raw.lastIndexOf('||');
  if (separator < 0) return raw;

  final name = raw.substring(0, separator).trim();
  final id = raw.substring(separator + 2).trim();
  if (!_uuid.hasMatch(id)) return raw;

  return name.isEmpty ? id : name;
}

/// Display text for a scanner field's codes: each one through
/// [teamCodeLabel], joined with ", ".
String formatScannedCodes(List<dynamic> codes) =>
    codes.map((code) => teamCodeLabel(code.toString())).join(', ');
