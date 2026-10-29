/// Display-only interpretation of a stock record. Never changes accounting.
class TransactionDetailsPresentation {
  final String entryType;
  final String reason;
  final String discrepancy;
  final num? original;
  final num? actual;
  final num? quantity;
  final String originalIssue;
  final String status;

  TransactionDetailsPresentation(List<dynamic> args)
      : entryType = _text(_at(args, 0)).toUpperCase(),
        reason = _text(_at(args, 1)).toUpperCase(),
        discrepancy = _text(_at(args, 2)).toUpperCase(),
        original = num.tryParse(_text(_at(args, 3))),
        actual = num.tryParse(_text(_at(args, 4))),
        quantity = num.tryParse(_text(_at(args, 5))),
        originalIssue = _text(_at(args, 6)),
        status = _text(_at(args, 7)).toUpperCase();

  static dynamic _at(List<dynamic> args, int index) =>
      index < args.length ? args[index] : null;

  static String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.toLowerCase() == 'null' ? '' : text;
  }

  bool get isLoss => entryType == 'LOSS' || reason == 'STOCK_LOSS';
  bool get isDamage => entryType == 'DAMAGED' || reason == 'STOCK_DAMAGE';
  bool get isShortfall =>
      (entryType == 'RETURNED' &&
          originalIssue.isNotEmpty &&
          {'STOCK_LOSS', 'STOCK_DAMAGE', 'IN_TRANSIT'}.contains(discrepancy)) ||
      reason == 'IN_TRANSIT' ||
      ((isLoss || isDamage) && (originalIssue.isNotEmpty || hasPartial));

  bool get isResolution => isShortfall || isLoss || isDamage;
  bool get hasPartial => original != null && actual != null;
  num? get sent => original ?? quantity;

  String get primaryLabel {
    if (isShortfall) return 'INVENTORY_DETAILS_SHORTFALL_REPORTED';
    if (isLoss) return 'APPONE_INVENTORY_QUANTITY_LOST_LABEL';
    if (isDamage) return 'APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL';
    return {
          'ISSUED': 'APPONE_INVENTORY_QUANTITY_SENT_LABEL',
          'DISPATCH': 'APPONE_INVENTORY_QUANTITY_SENT_LABEL',
          'RETURNED': 'APPONE_INVENTORY_QUANTITY_RETURNED_LABEL',
          'RECEIPT': 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL',
          'LESS': 'APPONE_INVENTORY_QUANTITY_LOST_LABEL',
          'EXCESS': 'INVENTORY_DETAILS_EXCESS_QUANTITY',
        }[entryType] ??
        'APPONE_INVENTORY_QUANTITY_LABEL';
  }

  String get confirmedLabel {
    if (isLoss) return 'INVENTORY_DETAILS_CONFIRMED_LOST';
    if (isDamage) return 'INVENTORY_DETAILS_CONFIRMED_DAMAGED';
    if (isShortfall) return 'INVENTORY_DETAILS_CONFIRMED_IN_TRANSIT';
    return 'INVENTORY_DETAILS_QUANTITY_RECEIVED';
  }

  num? get confirmedQuantity {
    if (!isShortfall) return isResolution ? null : actual;
    if (hasPartial) return actual;
    // Full write-off Accept stores actual=0 to indicate no physical receipt.
    // The entire reported quantity is confirmed, not that zero sentinel.
    return status == 'ACCEPTED' ? sent : null;
  }

  String get differenceLabel => isResolution
      ? 'INVENTORY_DETAILS_REMAINING_SHORTFALL'
      : 'INVENTORY_DETAILS_NOT_RECEIVED';

  num? get difference => hasPartial ? original! - actual! : null;

  /// Use the same rules for navigation from saved records and acceptance.
  static String heading(String type, String reason, String discrepancy,
      [String originalIssue = '']) {
    final presentation = TransactionDetailsPresentation(
        [type, reason, discrepancy, null, null, null, originalIssue]);
    if (presentation.isLoss) return 'INVENTORY_STOCK_LOSS_DETAILS_HEADING';
    if (presentation.isDamage) return 'INVENTORY_STOCK_DAMAGED_DETAILS_HEADING';
    if (presentation.isShortfall) return 'INVENTORY_DETAILS_SHORTFALL_HEADING';
    if ((type == 'ISSUED' || type == 'RETURNED') && reason == 'RECEIVED') {
      return 'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING';
    }
    return {
          'ISSUED': 'INVENTORY_STOCK_ISSUE_DETAILS_HEADING',
          'DISPATCH': 'INVENTORY_STOCK_ISSUE_DETAILS_HEADING',
          'RETURNED': 'INVENTORY_STOCK_RETURN_DETAILS_HEADING',
          'DAMAGED': 'INVENTORY_STOCK_DAMAGED_DETAILS_HEADING',
          'LOSS': 'INVENTORY_STOCK_LOSS_DETAILS_HEADING',
          'LESS': 'INVENTORY_STOCK_LOSS_DETAILS_HEADING',
          'EXCESS': 'INVENTORY_STOCK_EXCESS_DETAILS_HEADING',
        }[type] ??
        'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING';
  }

  static String acceptedHeading(String incomingType, String discrepancy) {
    if (incomingType == 'RETURNED') {
      if (discrepancy == 'STOCK_LOSS') {
        return heading('LOSS', 'STOCK_LOSS', discrepancy);
      }
      if (discrepancy == 'STOCK_DAMAGE') {
        return heading('DAMAGED', 'STOCK_DAMAGE', discrepancy);
      }
      if (discrepancy == 'IN_TRANSIT') {
        return heading('RETURNED', 'IN_TRANSIT', discrepancy);
      }
    }
    return heading(incomingType, 'RECEIVED', discrepancy);
  }
}
