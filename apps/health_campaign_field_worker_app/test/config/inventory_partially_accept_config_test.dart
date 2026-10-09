import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
void main() {
  late Map<String, dynamic> page;
  late List<dynamic> onSecondaryAction;

  setUpAll(() {
    final config = jsonDecode(
      File('assets/configs/json/INVENTORY.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    // The popup lives on the page; the actions it triggers live one level up
    // on the enclosing flow.
    final flow = (config['flows'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((f) => f['name'] == 'stockReceiptDetails');

    page = (flow['pages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['page'] == 'stockReceiptDetails');

    onSecondaryAction = flow['onSecondaryAction'] as List<dynamic>;
  });

  List<Map<String, dynamic>> bodyFields() =>
      ((page['showSecondaryAlertPopUp'] as Map)['body'] as List)
          .cast<Map<String, dynamic>>();

  Map<String, dynamic> modifyEntries() {
    final validBranch = onSecondaryAction
        .cast<Map<String, dynamic>>()
        .firstWhere(
            (action) => action['condition']?['expression'] != 'DEFAULT');
    final update = (validBranch['actions'] as List)
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
      'partial acceptance only proceeds for a positive quantity no greater than dispatched',
      () {
    final validBranch = onSecondaryAction
        .cast<Map<String, dynamic>>()
        .firstWhere(
            (action) => action['condition']?['expression'] != 'DEFAULT');

    expect(
      validBranch['condition']['expression'],
      'actualQuantityReceived > 0 && actualQuantityReceived <= quantity',
    );
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
    final modify = modifyEntries();

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
    expect(
      modify['StockModel.additionalFields.fields.comments'],
      '{{fn:safeString(formData.rejectComment)}}',
    );
  });

  test('every popup field is actually saved somewhere', () {
    // Catches a field being added to the popup but never wired into the
    // UPDATE_EVENT, which would silently discard what the user typed.
    final persisted = modifyEntries().values.map((v) => v.toString()).join(' ');
    for (final field in bodyFields()) {
      expect(persisted, contains('formData.${field['fieldName']}'),
          reason: '${field['fieldName']} is captured but never persisted');
    }
  });

  test(
      'partial accept creates a receiver receipt for the entered amount and updates stock balance',
      () {
    final validBranch = onSecondaryAction
        .cast<Map<String, dynamic>>()
        .firstWhere(
            (action) => action['condition']?['expression'] != 'DEFAULT');
    final actions =
        (validBranch['actions'] as List).cast<Map<String, dynamic>>();
    final fetch = actions.firstWhere(
      (action) => action['actionType'] == 'FETCH_TRANSFORMER_CONFIG',
    );
    final fetchProperties = fetch['properties'] as Map<String, dynamic>;
    final quantityData = (fetchProperties['data'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((entry) => entry['key'] == 'quantity');

    expect(fetchProperties['configName'], 'stockReceipt');
    expect(quantityData['value'], '{{formData.actualQuantityReceived}}');
    expect(actions.map((action) => action['actionType']), [
      'FETCH_TRANSFORMER_CONFIG',
      'UPDATE_EVENT',
      'UPDATE_STOCK_BALANCE',
      'SHOW_TOAST',
      'NAVIGATION',
    ]);
  });
}
