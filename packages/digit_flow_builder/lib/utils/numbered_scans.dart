/// UPDATE_EVENT `modify` key suffix that saves scanned codes one per field:
/// `{"key": "StockModel.additionalFields.numberedScans",
///   "value": "{{formData.<page>.<scannerField>}}"}`.
const numberedScansModifyField = 'numberedScans';

/// Turns a bale/piece scanner's value - one code per line,
/// "saveKey<TAB>code<TAB>…" (digit_scanner utils/scanned_stock.dart) - into
/// additionalFields entries numbered per saveKey in scan order:
/// baleScannedStock1, piecesScannedStock1, piecesScannedStock2, …
/// Anything else gives no entries.
Map<String, String> numberedScanFields(Object? value) {
  final fields = <String, String>{};
  if (value is! String) return fields;
  final counters = <String, int>{};
  for (final line in value.split('\n')) {
    final columns = line.split('\t');
    if (columns.length < 2) continue;
    final saveKey = columns[0].trim();
    final code = columns[1].trim();
    if (saveKey.isEmpty || code.isEmpty) continue;
    final n = (counters[saveKey] ?? 0) + 1;
    counters[saveKey] = n;
    fields['$saveKey$n'] = code;
  }
  return fields;
}
