/// Builds, parses and scope-validates the delivery-team (CDD) QR payload.
///
/// This library is deliberately import-free (pure Dart) so unit tests and the
/// flow-builder function registry can depend on it without pulling in the
/// widget/bloc graph. The context-aware payload builder
/// (`buildTeamQrPayload`) lives in `utils.dart`, which re-exports this
/// library.
///
/// Payload variants that must remain parseable forever:
///   v2:              "cdd01||9d54...#NG_TRB_WARD01||mz"   (current emit)
///   v2, no boundary: "cdd01||9d54...#||mz"
///   v1 (legacy):     "cdd01||9d54..."                     (old app versions)
///   bare uuid:       "9d54..."                            (no userName)
///   passthrough:     anything without "||"                (manual/facility codes)
///
/// [TeamQrCodec.extensionSeparator] ('#') splits the legacy half from the
/// extension half; [TeamQrCodec.fieldSeparator] ('||') splits fields inside
/// each half. The extension is consumed only by the scan-time scope validation
/// ([isTeamQrInScope]) and by external systems; everywhere else the app keeps
/// using only the userName (display, split('||').first) and the userUuid
/// ([TeamQrCodec.extractUserUuid], persisted as StockModel.receiverId).
///
/// A bare-uuid payload never carries an extension: display readers resolve the
/// team name via split('||').first, so "uuid#b||t" would render "uuid#b" as a
/// team name.
library;

class TeamQrCodec {
  TeamQrCodec._();

  static const String extensionSeparator = '#';
  static const String fieldSeparator = '||';

  /// Pure builder. Never throws.
  ///
  /// Emits "userName||userUuid#boundaryCode||tenantId"; positions stay fixed
  /// when [boundaryCode] or [tenantId] is empty ("name||uuid#||mz"). Degrades
  /// to the legacy "userName||userUuid" when both are empty, and to the bare
  /// uuid when [userName] is null/empty. Reserved separator characters are
  /// stripped from every segment so no input can corrupt the structure.
  static String buildPayload({
    required String? userName,
    required String userUuid,
    String boundaryCode = '',
    String tenantId = '',
  }) {
    final name = _sanitize(userName);
    final uuid = userUuid.trim();
    if (name.isEmpty) return uuid;
    final legacyHalf = '$name$fieldSeparator$uuid';
    final boundary = _sanitize(boundaryCode);
    final tenant = _sanitize(tenantId);
    if (boundary.isEmpty && tenant.isEmpty) return legacyHalf;
    return '$legacyHalf$extensionSeparator$boundary$fieldSeparator$tenant';
  }

  /// Extracts the bare user uuid from any payload variant. NEVER throws —
  /// called from the flow-builder 'getTeamCode' fn:, where an uncaught throw
  /// blanks the whole TEMPLATE screen. Strings without '||' pass through
  /// unchanged (historic getTeamCode behavior for manual/facility codes).
  static String extractUserUuid(dynamic raw) {
    final value = raw?.toString() ?? '';
    if (!value.contains(fieldSeparator)) return value.trim();
    final legacyHalf = value.split(extensionSeparator).first;
    if (!legacyHalf.contains(fieldSeparator)) return legacyHalf.trim();
    return legacyHalf.split(fieldSeparator).last.trim();
  }

  /// Parses the "#boundaryCode||tenantId" extension. Returns null — which the
  /// scan-time scope validation treats as reject — when the payload has no
  /// extension (legacy v1 / bare uuid) or is structurally malformed (no '||'
  /// in the legacy half, or no '||' in the extension half). Never throws.
  static TeamQrExtension? parseExtension(dynamic raw) {
    final value = raw?.toString() ?? '';
    final hashIndex = value.indexOf(extensionSeparator);
    if (hashIndex < 0) return null;
    final legacyHalf = value.substring(0, hashIndex);
    if (!legacyHalf.contains(fieldSeparator)) return null;
    final extensionHalf = value.substring(hashIndex + 1);
    final separatorIndex = extensionHalf.indexOf(fieldSeparator);
    if (separatorIndex < 0) return null;
    return TeamQrExtension(
      boundaryCode: extensionHalf.substring(0, separatorIndex).trim(),
      tenantId: extensionHalf
          .substring(separatorIndex + fieldSeparator.length)
          .trim(),
    );
  }

  /// Strips reserved separator characters ('#', '|') so no segment can
  /// corrupt the payload structure. Silent by design: a throw here would
  /// crash the drawer/QR-page build over a weird boundary code.
  static String _sanitize(String? value) => (value ?? '')
      .replaceAll(extensionSeparator, '')
      .replaceAll('|', '')
      .trim();
}

/// The scope half of a team QR payload — see [TeamQrCodec.parseExtension].
class TeamQrExtension {
  final String boundaryCode;
  final String tenantId;

  const TeamQrExtension({
    required this.boundaryCode,
    required this.tenantId,
  });
}

/// Pure scan-time scope check for a scanned team QR: the payload must carry
/// the extension (legacy QRs are rejected — strictness is the point of the
/// extension), its tenantId must equal the scanning user's tenant, and its
/// boundaryCode must be one of [scannerBoundaryCodes] (the scanning user's
/// selected-boundary chain plus covered least-level boundaries, so HF and CDD
/// selections at different hierarchy levels still match).
bool isTeamQrInScope(
  String scannedValue, {
  required Set<String> scannerBoundaryCodes,
  required String scannerTenantId,
}) {
  final extension = TeamQrCodec.parseExtension(scannedValue);
  if (extension == null) return false;
  final tenant = scannerTenantId.trim();
  if (tenant.isEmpty || extension.tenantId != tenant) return false;
  if (extension.boundaryCode.isEmpty) return false;
  return scannerBoundaryCodes.contains(extension.boundaryCode);
}
