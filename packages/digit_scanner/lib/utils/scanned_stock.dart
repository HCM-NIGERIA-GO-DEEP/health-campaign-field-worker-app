import 'package:gs1_barcode_parser/gs1_barcode_parser.dart';

import 'i18_key_constants.dart' as i18;

/// Bale/piece scanning ("typed" scanning): one scanner that accepts several
/// kinds of GS1 code and tells them apart by a GS1 field, e.g. a bale label's
/// SSCC carries (00) and a net's code carries (21).
///
/// A scanner field turns it on with a validation entry:
/// ```json
/// {"type": "scanTypes", "value": [
///   {"type": "bale", "ai": "00", "saveKey": "baleScannedStock", "label": "..."},
///   {"type": "piece", "ai": "21", "saveKey": "piecesScannedStock", "label": "..."}
/// ]}
/// ```
const scanTypesValidationType = 'scanTypes';

/// Scan count a typed scanner allows: in practice no limit.
const typedScanNoLimit = 1 << 30;

/// One kind of code a typed scanner accepts.
class ScanTypeRule {
  const ScanTypeRule({
    required this.type,
    required this.ai,
    required this.saveKey,
    this.label,
  });

  /// Kind name, e.g. "bale".
  final String type;

  /// GS1 Application Identifier a code must carry to be this kind; its value
  /// is the code's ID (SSCC for a bale, serial for a net).
  final String ai;

  /// Base of the additionalFields keys: saveKey1, saveKey2, …
  final String saveKey;

  /// Localization key shown for this kind.
  final String? label;

  /// Whether a stored saveKey is this rule's, scanned or typed by hand.
  bool owns(String key) =>
      key == saveKey || key == '$saveKey$manualSaveKeySuffix';
}

/// Appended to a rule's saveKey for codes typed on manual entry, so they are
/// saved apart from camera scans: baleScannedStockManual1, …
const manualSaveKeySuffix = 'Manual';

final _manualCodes = Expando<bool>('manualCode');

/// Marks [code] as typed on manual entry rather than scanned.
void markManualCode(GS1Barcode code) => _manualCodes[code] = true;

bool isManualCode(GS1Barcode code) => _manualCodes[code] ?? false;

/// Rules from a `scanTypes` validation value. Entries without a type, ai or
/// saveKey are dropped; anything that is not a list gives no rules.
List<ScanTypeRule> scanTypeRulesFrom(Object? value) {
  if (value is! List) return const [];
  final rules = <ScanTypeRule>[];
  for (final item in value) {
    if (item is! Map) continue;
    final type = item['type'];
    final ai = item['ai'];
    final saveKey = item['saveKey'];
    if (type is! String || ai is! String || saveKey is! String) continue;
    if (type.isEmpty || ai.isEmpty || saveKey.isEmpty) continue;
    final label = item['label'];
    rules.add(ScanTypeRule(
      type: type,
      ai: ai,
      saveKey: saveKey,
      label: label is String ? label : null,
    ));
  }
  return rules;
}

/// GS1 mod-10 check digit (last digit) of a numeric key such as an SSCC.
/// Used for a typed bale SSCC, where a typo would otherwise be saved; the
/// parser itself checks only the length and that it is digits.
bool hasValidGs1CheckDigit(String digits) {
  if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) return false;
  final body = digits.substring(0, digits.length - 1);
  final check = int.parse(digits[digits.length - 1]);
  var total = 0;
  for (var i = 0; i < body.length; i++) {
    final digit = int.parse(body[body.length - 1 - i]);
    total += digit * (i.isEven ? 3 : 1);
  }
  return (10 - total % 10) % 10 == check;
}

/// GS1 fields whose last digit is a mod-10 check digit: SSCC (00), GTIN (01)
/// and contained GTIN (02).
const _checkDigitAis = {'00', '01', '02'};

/// Whether every check-digit field of [code] has a correct check digit. The
/// parser checks only length and digits, so a camera misread such as
/// 146402178112799266 for the bale 176402178112799276 (QA, 2026-11-16) would
/// otherwise be saved as a second bale.
bool hasValidGs1Keys(GS1Barcode code) => code.elements.values
    .where((element) => _checkDigitAis.contains(element.aiCode))
    .every((element) => hasValidGs1CheckDigit(element.rawData));

/// Why a value typed on a typed scanner's manual entry was refused.
enum ManualCodeProblem {
  /// A number field (bale SSCC) holding anything but digits.
  notDigits,

  /// A number field with the wrong number of digits (an SSCC has 18).
  wrongLength,

  /// The right number of digits, but the last digit does not match.
  wrongCheckDigit,

  /// A serial (net) that is empty, too long, or has spaces or brackets.
  invalidSerial,

  /// A valid code, but of another kind than the one picked.
  otherKind,
}

/// The outcome of checking a typed code: [code] when accepted, otherwise
/// [problem].
class ManualCodeCheck {
  const ManualCodeCheck.accepted(GS1Barcode this.code, this.typed)
      : problem = null;

  const ManualCodeCheck.refused(ManualCodeProblem this.problem, this.typed)
      : code = null;

  final GS1Barcode? code;
  final ManualCodeProblem? problem;

  /// What was checked: the typed value without spaces and without a leading
  /// "(ai)" of the picked kind.
  final String typed;
}

/// Checks a value typed on a typed scanner's manual entry: only what was
/// typed, under the picked kind's GS1 field - (00) SSCC for a bale, (21)
/// serial for a piece; no GTIN, batch or expiry is made up, because the whole
/// code is saved. Spaces and a leading "(00)"/"(21)" of the picked kind are
/// dropped first, since the label prints the number that way.
///
/// Rules are compared by [ScanTypeRule.type], since the picked rule and
/// [rules] can be separate objects read from the same config.
ManualCodeCheck checkTypedManualCode(
  String value,
  ScanTypeRule picked,
  List<ScanTypeRule> rules,
) {
  var typed = value.replaceAll(RegExp(r'\s'), '');
  final prefix = '(${picked.ai})';
  if (typed.startsWith(prefix)) typed = typed.substring(prefix.length);

  if (_checkDigitAis.contains(picked.ai)) {
    if (!RegExp(r'^\d*$').hasMatch(typed)) {
      return ManualCodeCheck.refused(ManualCodeProblem.notDigits, typed);
    }
    final length = AI.AIS[picked.ai]?.fixLength ?? 0;
    if (typed.isEmpty || (length > 0 && typed.length != length)) {
      return ManualCodeCheck.refused(ManualCodeProblem.wrongLength, typed);
    }
    if (!hasValidGs1CheckDigit(typed)) {
      return ManualCodeCheck.refused(ManualCodeProblem.wrongCheckDigit, typed);
    }
  } else if (typed.isEmpty || typed.contains('(') || typed.contains(')')) {
    // GS1 allows brackets in a serial, so "(00)123" typed as a net would
    // otherwise be saved as serial "(00)123".
    return ManualCodeCheck.refused(ManualCodeProblem.invalidSerial, typed);
  }

  final GS1Barcode code;
  try {
    code = GS1BarcodeParser.defaultParser().parse('${picked.ai}$typed');
  } catch (_) {
    return ManualCodeCheck.refused(
        _checkDigitAis.contains(picked.ai)
            ? ManualCodeProblem.wrongLength
            : ManualCodeProblem.invalidSerial,
        typed);
  }
  return classifyScan(code, rules)?.type == picked.type
      ? ManualCodeCheck.accepted(code, typed)
      : ManualCodeCheck.refused(ManualCodeProblem.otherKind, typed);
}

/// The code for a value typed on manual entry, or null when
/// [checkTypedManualCode] refuses it.
GS1Barcode? typedManualCode(
  String value,
  ScanTypeRule picked,
  List<ScanTypeRule> rules,
) =>
    checkTypedManualCode(value, picked, rules).code;

/// English text for each refusal, used while its localization key has no
/// message. Placeholders: {kind} {ai} {expected} {count} {code}.
const _manualProblemDefaults = {
  ManualCodeProblem.notDigits:
      '{kind} number can only contain digits. Type the {expected} digits '
          'printed after ({ai}).',
  ManualCodeProblem.wrongLength:
      '{kind} number must be {expected} digits. You typed {count}.',
  ManualCodeProblem.wrongCheckDigit:
      '{kind} number {code} is not valid: a digit is wrong or two digits '
          'are swapped. Check it against the label.',
  ManualCodeProblem.invalidSerial:
      '{kind} serial must be 1 to 20 letters or digits, typed after ({ai}), '
          'with no spaces or brackets.',
};

final _manualProblemKeys = {
  ManualCodeProblem.notDigits: i18.scanner.manualCodeNotDigits,
  ManualCodeProblem.wrongLength: i18.scanner.manualCodeWrongLength,
  ManualCodeProblem.wrongCheckDigit: i18.scanner.manualCodeWrongCheckDigit,
  ManualCodeProblem.invalidSerial: i18.scanner.manualSerialInvalid,
};

/// The message telling the user what is wrong with a refused typed code.
/// [translate] returns the key itself when it has no message (as
/// ScannerLocalization does); the English default is used then. A code of
/// another kind gets [otherKindMessage] (the scanner's unknown-code message).
String manualCodeProblemMessage(
  ManualCodeCheck check,
  ScanTypeRule picked,
  String Function(String key) translate, {
  required String otherKindMessage,
}) {
  final problem = check.problem;
  if (problem == null) return '';
  if (problem == ManualCodeProblem.otherKind) return otherKindMessage;

  final key = _manualProblemKeys[problem]!;
  final translated = translate(key);
  final template = translated.trim().isEmpty || translated == key
      ? _manualProblemDefaults[problem]!
      : translated;

  final label = picked.label == null ? null : translate(picked.label!);
  final kind = label != null && label.trim().isNotEmpty && label != picked.label
      ? label
      : picked.type.isEmpty
          ? picked.type
          : picked.type[0].toUpperCase() + picked.type.substring(1);
  final expected = AI.AIS[picked.ai]?.fixLength ?? 0;

  return template
      .replaceAll('{kind}', kind)
      .replaceAll('{ai}', picked.ai)
      .replaceAll('{expected}', '$expected')
      .replaceAll('{count}', '${check.typed.length}')
      .replaceAll('{code}', check.typed);
}

/// The first rule whose GS1 field the code carries, or null.
ScanTypeRule? classifyScan(GS1Barcode code, List<ScanTypeRule> rules) {
  for (final rule in rules) {
    if (code.hasAI(rule.ai)) return rule;
  }
  return null;
}

/// The code as printed under a barcode, e.g. "(00)176402178112799276".
/// Built from the raw field text, so a date such as (11)250400 (day 00 =
/// day not given) is kept as is - the parser would turn it into 31 Mar 2025.
String gs1HumanReadable(GS1Barcode code) => code.elements.values
    .map((element) => '(${element.aiCode})${element.rawData}')
    .join();

/// The code as a scanner reads it (AI + value, with a group separator after
/// each variable-length field but the last), so it can be parsed again.
String gs1ElementString(GS1Barcode code) {
  const groupSeparator = '\x1d';
  final elements = code.elements.values.toList();
  final buffer = StringBuffer();
  for (var i = 0; i < elements.length; i++) {
    final element = elements[i];
    buffer
      ..write(element.aiCode)
      ..write(element.rawData);
    final isVariable = (AI.AIS[element.aiCode]?.fixLength ?? 0) == 0;
    if (isVariable && i < elements.length - 1) buffer.write(groupSeparator);
  }
  return buffer.toString();
}

/// One scanned bale or piece as kept in the scanner field's form value.
class ScannedStockEntry {
  const ScannedStockEntry({
    required this.saveKey,
    required this.code,
    required this.raw,
  });

  final String saveKey;

  /// Readable full code, saved as the additionalFields value.
  final String code;

  /// Element string, to rebuild the barcode when the scanner reopens.
  final String raw;

  /// What identifies the item on screen: the serial (21) when the code has
  /// one (a net), otherwise its first field (a bale's SSCC (00)).
  String get id {
    final fields = RegExp(r'\((\d{2,4})\)([^(]*)').allMatches(code).toList();
    if (fields.isEmpty) return code;
    final serial = fields.where((m) => m.group(1) == '21');
    return (serial.isNotEmpty ? serial.first : fields.first).group(2)!;
  }
}

/// The entry for a scanned code, or null when no rule takes it.
ScannedStockEntry? scannedStockEntryFor(
  GS1Barcode code,
  List<ScanTypeRule> rules,
) {
  final rule = classifyScan(code, rules);
  if (rule == null) return null;
  return ScannedStockEntry(
    saveKey: isManualCode(code)
        ? '${rule.saveKey}$manualSaveKeySuffix'
        : rule.saveKey,
    code: gs1HumanReadable(code),
    raw: gs1ElementString(code),
  );
}

// Form value: one line per code, "saveKey<TAB>code<TAB>raw". Tabs and line
// breaks cannot occur in GS1 data. The transformer's __numberedScans:
// directive reads the first two columns.
const _columnSeparator = '\t';
const _lineSeparator = '\n';

String encodeScannedStock(List<ScannedStockEntry> entries) => entries
    .map((e) => [e.saveKey, e.code, e.raw].join(_columnSeparator))
    .join(_lineSeparator);

List<ScannedStockEntry> decodeScannedStock(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  final entries = <ScannedStockEntry>[];
  for (final line in value.split(_lineSeparator)) {
    final columns = line.split(_columnSeparator);
    if (columns.length < 3) continue;
    if (columns[0].isEmpty || columns[1].isEmpty) continue;
    entries.add(ScannedStockEntry(
      saveKey: columns[0],
      code: columns[1],
      raw: columns[2],
    ));
  }
  return entries;
}

/// Barcodes for the scanner page when it reopens; codes that no longer parse
/// are left out rather than failing the page.
List<GS1Barcode> barcodesFromScannedStock(String? value) {
  final parser = GS1BarcodeParser.defaultParser();
  final barcodes = <GS1Barcode>[];
  for (final entry in decodeScannedStock(value)) {
    try {
      final code = parser.parse(entry.raw);
      if (entry.saveKey.endsWith(manualSaveKeySuffix)) markManualCode(code);
      barcodes.add(code);
    } catch (_) {
      // A stored code that cannot be parsed is skipped.
    }
  }
  return barcodes;
}

/// How many codes of each kind the value holds, keyed by rule type, in rule
/// order.
Map<String, int> scannedStockCounts(String? value, List<ScanTypeRule> rules) {
  final entries = decodeScannedStock(value);
  return {
    for (final rule in rules)
      rule.type: entries.where((e) => rule.owns(e.saveKey)).length,
  };
}
