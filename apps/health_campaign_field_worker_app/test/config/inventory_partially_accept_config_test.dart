import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';

/// Guards the stock-receipt secondary action, which is now a *partial*
/// acceptance rather than an outright rejection: the storekeeper records how
/// many units actually arrived, plus why the count differs.
///
/// Both values are written onto the receiving StockModel's additionalFields
/// by the UPDATE_EVENT on the page's onSecondaryAction.
///
/// Note the popup renderer previously shared a single TextEditingController
/// across all body fields, so a second field was not merely unsupported - it
/// would have silently received the first field's text. See
/// forms_render.dart `_showSecondaryAlertPopUp`.
///
/// `onSecondaryAction` has several branches, evaluated in order (first match
/// wins):
///   1. RETURNED + discrepancyReason == STOCK_LOSS: upper-hierarchy write-off
///      of an incoming shortfall return. Always writes quantity 0 regardless
///      of what was typed - it's a terminal write-off, not a real partial
///      accept.
///   2. RETURNED (any other/no discrepancy reason): rejected with
///      INVENTORY_PARTIAL_ACCEPT_RETURN_REQUIRES_STOCK_LOSS_REASON - partial
///      accept on a return is only valid as a stock-loss write-off.
///   3. Non-RETURNED, with an out-of-range quantity (<= 0 or >= the
///      dispatched quantity): rejected with
///      INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID. This is the real "partial
///      accept" guard - it blocks submitting with nothing received, or with
///      everything received (that's the primary Accept action instead).
///   4. Non-RETURNED, quantity strictly between 0 and the dispatched
///      quantity: the actual partial-accept path - creates a receiver
///      receipt for the amount received and a shortfall/return transaction
///      for the remainder.
///   5. DEFAULT: catch-all, also shows INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID.
///
/// Tests below identify branches by their condition expression rather than
/// positionally, since the array's exact order (while meaningful - earlier,
/// more specific branches must come first) shouldn't be load-bearing for
/// what each branch *does*.
void main() {
  late Map<String, dynamic> flow;
  late Map<String, dynamic> page;
  late List<Map<String, dynamic>> onSecondaryAction;

  setUpAll(() {
    final flows = (sampleInventoryFlows['flows'] as List)
        .cast<Map<String, dynamic>>();
    flow = flows.firstWhere((f) => f['name'] == 'stockReceiptDetails');

    page = (flow['pages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['page'] == 'stockReceiptDetails');

    onSecondaryAction =
        (flow['onSecondaryAction'] as List).cast<Map<String, dynamic>>();
  });

  List<Map<String, dynamic>> bodyFields() =>
      ((page['showSecondaryAlertPopUp'] as Map)['body'] as List)
          .cast<Map<String, dynamic>>();

  String expressionOf(Map<String, dynamic> branch) =>
      (branch['condition'] as Map)['expression'] as String;

  /// The branch that performs the actual (non-RETURNED) partial accept: its
  /// condition references both `actualQuantityReceived` and `quantity` with
  /// range comparisons, and is not the RETURNED-specific out-of-range guard.
  Map<String, dynamic> partialAcceptBranch() => onSecondaryAction.firstWhere(
        (action) =>
            expressionOf(action).contains('actualQuantityReceived') &&
            expressionOf(action).contains('quantity') &&
            !expressionOf(action).contains('incomingStockEntryType'),
      );

  /// The branch that rejects an out-of-range quantity for the generic
  /// (non-RETURNED) partial accept.
  Map<String, dynamic> invalidQuantityBranch() => onSecondaryAction.firstWhere(
        (action) =>
            expressionOf(action).contains('incomingStockEntryType') &&
            expressionOf(action).contains('actualQuantityReceived'),
      );

  Map<String, dynamic> modifyEntriesOf(Map<String, dynamic> branch) {
    final update = (branch['actions'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((action) => action['actionType'] == 'UPDATE_EVENT');
    final modify =
        (update['properties']['modify'] as List).cast<Map<String, dynamic>>();
    return {for (final m in modify) m['key'] as String: m['value']};
  }

  test('the secondary action reads as a partial acceptance, not a rejection',
      () {
    expect(
        page['secondaryActionLabel'], 'INVENTORY_PARTIALLY_ACCEPT_STOCK_LABEL');
  });

  test(
      'partial acceptance only proceeds for a positive quantity strictly less than dispatched',
      () {
    expect(
      expressionOf(partialAcceptBranch()),
      'actualQuantityReceived > 0 && actualQuantityReceived < quantity',
    );
  });

  test(
      'a zero or out-of-range quantity is rejected with an explicit error, not silently ignored',
      () {
    final branch = invalidQuantityBranch();
    expect(
      expressionOf(branch),
      "navigation.incomingStockEntryType != 'RETURNED' && "
      "(actualQuantityReceived <= 0 || actualQuantityReceived >= quantity)",
    );

    final toast = (branch['actions'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((action) => action['actionType'] == 'SHOW_TOAST');
    expect(
      toast['properties']['message'],
      'INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID',
    );
    expect(toast['properties']['type'], 'error');

    // The invalid-quantity guard must run before the generic partial-accept
    // branch, otherwise an in-range match further down could never be
    // reached for the cases this guard is meant to intercept.
    expect(
      onSecondaryAction.indexOf(branch),
      lessThan(onSecondaryAction.indexOf(partialAcceptBranch())),
    );
  });

  test(
      'the DEFAULT branch remains a catch-all, not the mechanism for rejecting 0/over-quantity',
      () {
    final defaultBranch =
        onSecondaryAction.firstWhere((a) => expressionOf(a) == 'DEFAULT');
    final toast = (defaultBranch['actions'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((action) => action['actionType'] == 'SHOW_TOAST');
    expect(
      toast['properties']['message'],
      'INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID',
    );
    // DEFAULT must be the last branch so it never shadows a real case.
    expect(onSecondaryAction.last, same(defaultBranch));
  });

  test('the popup captures both a quantity and a comment', () {
    final byName = {for (final f in bodyFields()) f['fieldName']: f};

    expect(
        byName.keys, containsAll(['actualQuantityReceived', 'rejectComment']));
    expect(byName['actualQuantityReceived']!['format'], 'numeric');
    expect(byName['rejectComment']!['format'], 'textArea');
  });

  test('both popup fields are mandatory', () {
    for (final field in bodyFields()) {
      expect(field['mandatory'], isTrue,
          reason: '${field['fieldName']} should be required');
    }
  });

  test('each popup field has a distinct fieldName', () {
    // Two fields sharing a name would collide in the popupData map and only
    // one value would survive.
    final names = bodyFields().map((f) => f['fieldName']).toList();
    expect(names.toSet().length, names.length);
  });

  test('both values are persisted onto the stock additionalFields', () {
    final modify = modifyEntriesOf(partialAcceptBranch());

    expect(
      modify['StockModel.additionalFields.fields.actualQuantityReceived'],
      '{{fn:safeString(formData.actualQuantityReceived)}}',
    );
    expect(
      modify['StockModel.additionalFields.fields.status'],
      'ACCEPTED',
    );
    expect(
      modify['StockModel.additionalFields.fields.originalQuantityReceived'],
      '{{fn:safeString(navigation.quantity)}}',
    );
    expect(
      modify['StockModel.additionalFields.fields.comments'],
      '{{fn:safeString(formData.rejectComment)}}',
    );
  });

  test('every popup field is actually saved somewhere', () {
    // Catches a field being added to the popup but never wired into an
    // UPDATE_EVENT or FETCH_TRANSFORMER_CONFIG, which would silently discard
    // what the user typed. discrepancyReason in particular only flows
    // through the shortfallTransaction FETCH_TRANSFORMER_CONFIG's data, not
    // the UPDATE_EVENT modify list, so both action types must be scanned.
    final actions =
        (partialAcceptBranch()['actions'] as List).cast<Map<String, dynamic>>();
    final persistedValues = <String>[];
    for (final action in actions) {
      final properties = action['properties'] as Map<String, dynamic>?;
      if (properties == null) continue;
      if (action['actionType'] == 'UPDATE_EVENT') {
        final modify = (properties['modify'] as List?) ?? [];
        persistedValues.addAll(modify
            .cast<Map<String, dynamic>>()
            .map((m) => m['value'].toString()));
      } else if (action['actionType'] == 'FETCH_TRANSFORMER_CONFIG') {
        final data = (properties['data'] as List?) ?? [];
        persistedValues.addAll(
            data.cast<Map<String, dynamic>>().map((d) => d['value'].toString()));
      }
    }
    final persisted = persistedValues.join(' ');
    for (final field in bodyFields()) {
      expect(persisted, contains('formData.${field['fieldName']}'),
          reason: '${field['fieldName']} is captured but never persisted');
    }
  });

  test(
      'partial accept creates a receiver receipt for the entered amount and updates stock balance',
      () {
    final branch = partialAcceptBranch();
    final actions = (branch['actions'] as List).cast<Map<String, dynamic>>();
    final fetch = actions.firstWhere(
      (action) => action['actionType'] == 'FETCH_TRANSFORMER_CONFIG',
    );
    final fetchProperties = fetch['properties'] as Map<String, dynamic>;
    final quantityData = (fetchProperties['data'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((entry) => entry['key'] == 'quantity');

    expect(fetchProperties['configName'], 'stockReceipt');
    expect(quantityData['value'], '{{formData.actualQuantityReceived}}');
    expect(
      actions.map((action) => action['actionType']),
      containsAllInOrder([
        'FETCH_TRANSFORMER_CONFIG',
        'UPDATE_EVENT',
        'UPDATE_STOCK_BALANCE',
        'NAVIGATION',
      ]),
    );
  });

  test(
      'partial accept ends on the stockSuccess acknowledgment screen, same as '
      'any other transaction, instead of a bare toast', () {
    final branch = partialAcceptBranch();
    final actions = (branch['actions'] as List).cast<Map<String, dynamic>>();
    final navigation = actions.last;

    expect(navigation['actionType'], 'NAVIGATION');
    expect(navigation['properties']['name'], 'stockSuccess');
    expect(navigation['properties']['popUntilPageName'], 'manageStock');
  });
}
