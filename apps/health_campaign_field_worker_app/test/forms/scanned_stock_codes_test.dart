// ignore_for_file: depend_on_referenced_packages
import 'package:digit_scanner/utils/scanned_stock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs1_barcode_parser/gs1_barcode_parser.dart';

/// Sierra Leone ITN: on the stock Accept screen one scanner takes bales and
/// pieces (nets). The kind comes from the GS1 field on the code (config):
/// a bale label's SSCC carries (00), a net's code carries (21). Codes below
/// are copied from the two inspection-report labels (lots 1 and 4).
void main() {
  const gs = '\x1d';
  // Bale label, SSCC barcode: (00)176402178112799276
  const baleSscc = ']C100176402178112799276';
  // Bale label, contents barcode: (02)…(37)50(11)250400(10)104925 - same on
  // every bale of a batch, so it is not a bale identity.
  const baleContents = '020764021781161237' '50' '${gs}11250400' '10104925';
  // Net DataMatrix: (01)07640217811612(11)250400(10)104925(21)32ABD3F11
  const netLot1 = ']d2010764021781161211250400' '10104925${gs}2132ABD3F11';
  const netLot4 = '010764021781161211250600' '10600725${gs}215EF6E92D5';

  final rules = scanTypeRulesFrom([
    {
      'type': 'bale',
      'ai': '00',
      'saveKey': 'baleScannedStock',
      'label': 'INVENTORY_SCAN_TYPE_BALE',
    },
    {
      'type': 'piece',
      'ai': '21',
      'saveKey': 'piecesScannedStock',
      'label': 'INVENTORY_SCAN_TYPE_PIECE',
    },
  ]);

  GS1Barcode parse(String code) => GS1BarcodeParser.defaultParser().parse(code);

  group('scanTypeRulesFrom', () {
    test('reads the configured rules in order', () {
      expect(rules.map((r) => r.type), ['bale', 'piece']);
      expect(rules.first.ai, '00');
      expect(rules.last.saveKey, 'piecesScannedStock');
      expect(rules.first.label, 'INVENTORY_SCAN_TYPE_BALE');
    });

    test('drops entries it cannot use, never throws', () {
      expect(scanTypeRulesFrom(null), isEmpty);
      expect(scanTypeRulesFrom('bale'), isEmpty);
      expect(
          scanTypeRulesFrom([
            {'type': 'bale', 'ai': '00'}, // no saveKey
            {'type': 'piece', 'saveKey': 'p'}, // no ai
            'x',
            {'type': 'piece', 'ai': '21', 'saveKey': 'p'},
          ]).map((r) => r.type),
          ['piece']);
    });
  });

  group('classifyScan', () {
    test('a bale SSCC is a bale and a net code is a piece', () {
      expect(classifyScan(parse(baleSscc), rules)?.type, 'bale');
      expect(classifyScan(parse(netLot1), rules)?.type, 'piece');
      expect(classifyScan(parse(netLot4), rules)?.type, 'piece');
    });

    test("the bale's contents barcode is neither", () {
      expect(classifyScan(parse(baleContents), rules), isNull);
    });

    test('without rules nothing is classified', () {
      expect(classifyScan(parse(netLot1), const []), isNull);
    });
  });

  group('gs1HumanReadable', () {
    test('keeps every field exactly as printed, day 00 included', () {
      expect(gs1HumanReadable(parse(baleSscc)), '(00)176402178112799276');
      expect(gs1HumanReadable(parse(netLot1)),
          '(01)07640217811612(11)250400(10)104925(21)32ABD3F11');
    });
  });

  group('gs1ElementString', () {
    test('parses back to the same code', () {
      for (final code in [baleSscc, baleContents, netLot1, netLot4]) {
        final original = parse(code);
        final rebuilt = parse(gs1ElementString(original));
        expect(gs1HumanReadable(rebuilt), gs1HumanReadable(original),
            reason: code);
      }
    });
  });

  group('hasValidGs1CheckDigit (typed SSCC)', () {
    test('accepts the SSCCs printed on both labels', () {
      expect(hasValidGs1CheckDigit('176402178112799276'), isTrue); // lot 1
      expect(hasValidGs1CheckDigit('176402178115603969'), isTrue); // lot 4
    });

    test('rejects a one-digit typo, a swapped pair, empty or non-digits', () {
      expect(hasValidGs1CheckDigit('176402178112799275'), isFalse);
      expect(hasValidGs1CheckDigit('176402178112792976'), isFalse); // 9<->2
      expect(hasValidGs1CheckDigit(''), isFalse);
      expect(hasValidGs1CheckDigit('1764021781127992X6'), isFalse);
    });
  });

  group('typedManualCode (manual entry on the scanner page)', () {
    // The page reads its rules from config each time, so the picked rule and
    // the rules it classifies with are separate objects - as here.
    List<ScanTypeRule> freshRules() => scanTypeRulesFrom([
          {'type': 'bale', 'ai': '00', 'saveKey': 'baleScannedStock'},
          {'type': 'piece', 'ai': '21', 'saveKey': 'piecesScannedStock'},
        ]);
    ScanTypeRule picked(String type) =>
        freshRules().firstWhere((r) => r.type == type);

    test('a valid SSCC typed as a bale is accepted as a bale', () {
      final code =
          typedManualCode('176402178112799276', picked('bale'), freshRules());
      expect(code, isNotNull);
      expect(gs1HumanReadable(code!), '(00)176402178112799276');
    });

    test('a serial typed as a piece is accepted as a piece', () {
      final code = typedManualCode('32ABD3F11', picked('piece'), freshRules());
      expect(gs1HumanReadable(code!), '(21)32ABD3F11');
    });

    test('a mistyped, short or non-numeric SSCC is refused', () {
      for (final bad in [
        '176402178112799275',
        '17640217811279927',
        '1764021781127992X6',
        '',
      ]) {
        expect(typedManualCode(bad, picked('bale'), freshRules()), isNull,
            reason: bad);
      }
    });
  });

  group('scanned stock form value', () {
    ScannedStockEntry entryOf(String code) =>
        scannedStockEntryFor(parse(code), rules)!;

    test('an entry carries its save key, readable code and ID', () {
      final bale = entryOf(baleSscc);
      expect(bale.saveKey, 'baleScannedStock');
      expect(bale.code, '(00)176402178112799276');
      expect(bale.id, '176402178112799276');
      expect(entryOf(netLot1).id, '32ABD3F11');
      expect(scannedStockEntryFor(parse(baleContents), rules), isNull);
    });

    test('encodes and decodes in scan order', () {
      final entries = [entryOf(netLot1), entryOf(baleSscc), entryOf(netLot4)];
      final decoded = decodeScannedStock(encodeScannedStock(entries));
      expect(decoded.map((e) => e.code), entries.map((e) => e.code));
      expect(decoded.map((e) => e.saveKey), entries.map((e) => e.saveKey));
      expect(decoded.map((e) => e.id), entries.map((e) => e.id));
    });

    test('a typed code keeps its Manual key when the scanner reopens', () {
      final typed = typedManualCode('123456789987654321', rules.first, rules)!;
      markManualCode(typed);
      final value = encodeScannedStock(
          [entryOf(baleSscc), scannedStockEntryFor(typed, rules)!]);

      // Reopening rebuilds the codes from the value, then saves them again.
      final again = encodeScannedStock(barcodesFromScannedStock(value)
          .map((code) => scannedStockEntryFor(code, rules)!)
          .toList());
      expect(decodeScannedStock(again).map((e) => e.saveKey),
          ['baleScannedStock', 'baleScannedStockManual']);
      expect(scannedStockCounts(again, rules), {'bale': 2, 'piece': 0});
      expect(rules.first.owns('baleScannedStockManual'), isTrue);
      expect(rules.last.owns('baleScannedStockManual'), isFalse);
    });

    test('decoding skips blank or broken lines', () {
      expect(decodeScannedStock(null), isEmpty);
      expect(decodeScannedStock(''), isEmpty);
      expect(decodeScannedStock('only-one-column\n\n'), isEmpty);
    });

    test('decoded entries rebuild into the scanned barcodes', () {
      final value = encodeScannedStock([entryOf(baleSscc), entryOf(netLot1)]);
      final barcodes = barcodesFromScannedStock(value);
      expect(barcodes.map(gs1HumanReadable),
          ['(00)176402178112799276', gs1HumanReadable(parse(netLot1))]);
    });

    test('counts per kind, in rule order', () {
      final value = encodeScannedStock(
          [entryOf(netLot1), entryOf(baleSscc), entryOf(netLot4)]);
      expect(scannedStockCounts(value, rules), {'bale': 1, 'piece': 2});
    });
  });
}
