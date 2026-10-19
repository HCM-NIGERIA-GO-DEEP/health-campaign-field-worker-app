import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/manage_stock.dart';

/// Covers the Shortfall Return / re-issue loop on top of the plain
/// partial-accept coverage in inventory_partially_accept_config_test.dart.
///
/// Product spec under test (Stock PRD, "Partial Accept + Shortfall"):
///
///   2b. Lower hierarchy Partial Accepts an incoming dispatch (only part of
///       it arrived): the original record is updated in place to the
///       accepted quantity and ACCEPTED, and a brand-new "shortfallTransaction"
///       StockModel is created - stockEntryType RETURNED, quantity =
///       dispatched - accepted, sender = the accepting (lower) facility,
///       receiver = the original sender (upper) facility, status IN_TRANSIT -
///       so it shows up in the upper hierarchy's incoming list.
///   3a. Upper hierarchy Accepts that incoming Shortfall Return with reason
///       In-transit loss/Miscount/Others: a new re-issue shortfallTransaction
///       is created (stockEntryType ISSUED, same quantity, sender/receiver
///       swapped back), looping into step 2 for the lower hierarchy again.
///   3b. Upper hierarchy Accepts the same return with reason Stock damage:
///       no new transaction - the existing return record is mutated in place
///       to stockEntryType DAMAGED, ACCEPTED.
///   3c. Upper hierarchy Partial Accepts the return with reason Stock Loss
///       (the only valid reason for a RETURNED partial accept): the record is
///       zeroed out (quantity 0) and ACCEPTED - a terminal write-off.
///   3d. Upper hierarchy Partial Accepts the return with any other reason:
///       blocked with an explicit error, no side effects.
///
/// Every FETCH_TRANSFORMER_CONFIG that builds a *new* entity (as opposed to
/// UPDATE_EVENT's source: "existingModels", which mutates the record already
/// in hand) must be immediately followed by a CREATE_EVENT, otherwise the
/// entity is built in memory and silently never persisted. This file asserts
/// that pairing explicitly for every shortfallTransaction fetch, since that
/// exact omission was already found and fixed once in this file.
void main() {
  late List<Map<String, dynamic>> onAction;
  late List<Map<String, dynamic>> onSecondaryAction;

  setUpAll(() {
    final flows =
        (sampleInventoryFlows['flows'] as List).cast<Map<String, dynamic>>();
    final flow = flows.firstWhere((f) => f['name'] == 'stockReceiptDetails');

    onAction = (flow['onAction'] as List).cast<Map<String, dynamic>>();
    onSecondaryAction =
        (flow['onSecondaryAction'] as List).cast<Map<String, dynamic>>();
  });

  String? conditionOf(Map<String, dynamic> branch) =>
      (branch['condition'] as Map?)?['expression'] as String?;

  List<Map<String, dynamic>> actionsOf(Map<String, dynamic> branch) =>
      (branch['actions'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> dataEntry(Map<String, dynamic> fetchAction, String key) {
    final data = (fetchAction['properties']['data'] as List)
        .cast<Map<String, dynamic>>();
    return data.firstWhere((d) => d['key'] == key);
  }

  Map<String, dynamic> modifyEntry(
      Map<String, dynamic> updateAction, String key) {
    final modify = (updateAction['properties']['modify'] as List)
        .cast<Map<String, dynamic>>();
    return modify.firstWhere((m) => m['key'] == key);
  }

  /// Asserts that every FETCH_TRANSFORMER_CONFIG for [configName] appearing
  /// in [actions] is immediately (or at least eventually, before any
  /// UPDATE_STOCK_BALANCE) followed by a CREATE_EVENT - guards against
  /// regressing the already-fixed "built but never persisted" bug.
  void expectFetchFollowedByCreate(
    List<Map<String, dynamic>> actions,
    String configName, {
    required String reason,
  }) {
    final fetchIndex = actions.indexWhere((a) =>
        a['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
        a['properties']['configName'] == configName);
    expect(fetchIndex, greaterThanOrEqualTo(0),
        reason: 'expected a FETCH_TRANSFORMER_CONFIG($configName): $reason');

    final createIndex = actions.indexWhere(
      (a) => a['actionType'] == 'CREATE_EVENT',
      fetchIndex,
    );
    expect(createIndex, greaterThan(fetchIndex),
        reason: 'FETCH_TRANSFORMER_CONFIG($configName) at index $fetchIndex '
            'must be followed by a CREATE_EVENT or the built entity is never '
            'persisted: $reason');
  }

  group('Step 2b: lower hierarchy partial accept creates a Shortfall Return',
      () {
    Map<String, dynamic> branch() => onSecondaryAction.firstWhere(
          (a) =>
              (conditionOf(a) ?? '').contains('actualQuantityReceived') &&
              (conditionOf(a) ?? '').contains('quantity') &&
              !(conditionOf(a) ?? '').contains('incomingStockEntryType'),
        );

    test('is gated on a strictly-partial quantity (not RETURNED-specific)',
        () {
      expect(
        conditionOf(branch()),
        'actualQuantityReceived > 0 && actualQuantityReceived < quantity',
      );
    });

    test('original record is updated to the accepted quantity and ACCEPTED',
        () {
      final update = actionsOf(branch()).firstWhere(
        (a) =>
            a['actionType'] == 'UPDATE_EVENT' &&
            a['properties']['source'] == 'existingModels',
      );
      expect(
        modifyEntry(update, 'StockModel.quantity')['value'],
        '{{fn:safeString(formData.actualQuantityReceived)}}',
      );
      expect(
        modifyEntry(update, 'StockModel.additionalFields.fields.status')
            ['value'],
        'ACCEPTED',
      );
    });

    test(
        'a new shortfallTransaction is fetched for the shortfall amount, '
        'RETURNED, sender=accepting facility, receiver=original sender, '
        'and is followed by a CREATE_EVENT', () {
      final actions = actionsOf(branch());
      expectFetchFollowedByCreate(
        actions,
        'shortfallTransaction',
        reason: 'step 2b must persist the shortfall return it builds',
      );

      final fetch = actions.firstWhere((a) =>
          a['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
          a['properties']['configName'] == 'shortfallTransaction');

      expect(
        dataEntry(fetch, 'stockEntryType')['value'],
        'RETURNED',
        reason: 'the shortfall goes back to the upper hierarchy as a return',
      );
      expect(
        dataEntry(fetch, 'quantity')['value'],
        '{{fn:subtractQuantity(navigation.quantity, formData.actualQuantityReceived)}}',
        reason: 'shortfall quantity must be dispatched minus accepted',
      );
      expect(
        dataEntry(fetch, 'senderFacilityId')['value'],
        '{{fn:getUserFacilityId()}}',
        reason:
            'the lower hierarchy (current user) is the sender of the return',
      );
      expect(
        dataEntry(fetch, 'receiverFacilityId')['value'],
        '{{navigation.senderFacilityId}}',
        reason: 'the return goes back to the original (upper) sender',
      );
    });

    test(
        'UPDATE_STOCK_BALANCE runs between the two FETCH_TRANSFORMER_CONFIG '
        'calls in this branch, while entities still holds the Received '
        'entity', () {
      // Fixed action order: UPDATE_STOCK_BALANCE must run right after the
      // first UPDATE_EVENT (which persists the original dispatch record's
      // mutation to ACCEPTED/qty=actualQuantityReceived and does not touch
      // contextData['entities']) and BEFORE the second
      // FETCH_TRANSFORMER_CONFIG(shortfallTransaction) overwrites entities
      // with the Shortfall Return entity. This way the balance update only
      // ever sees the "Received" entity built by the first
      // FETCH_TRANSFORMER_CONFIG(stockReceipt) call, correctly crediting the
      // accepting facility with the quantity it actually received and never
      // touching the Shortfall Return entity (which, per
      // stock_balance_executor's isDistributorReturn routing, would
      // otherwise incorrectly debit the accepting facility by the shortfall
      // amount).
      final actions = actionsOf(branch());
      final fetchIndices = <int>[];
      for (var i = 0; i < actions.length; i++) {
        if (actions[i]['actionType'] == 'FETCH_TRANSFORMER_CONFIG') {
          fetchIndices.add(i);
        }
      }
      final balanceIndex =
          actions.indexWhere((a) => a['actionType'] == 'UPDATE_STOCK_BALANCE');

      expect(fetchIndices.length, 2,
          reason: 'expected stockReceipt + shortfallTransaction fetches');
      expect(balanceIndex, greaterThan(fetchIndices.first),
          reason: 'UPDATE_STOCK_BALANCE must run after the stockReceipt '
              'fetch has populated entities with the Received entity');
      expect(balanceIndex, lessThan(fetchIndices.last),
          reason:
              'UPDATE_STOCK_BALANCE must run before the shortfallTransaction '
              'fetch overwrites entities, so it only ever sees the Received '
              'entity (correct +actualQuantityReceived), never the Shortfall '
              'Return entity (which would incorrectly debit the accepting '
              'facility)');

      final createIndex =
          actions.indexWhere((a) => a['actionType'] == 'CREATE_EVENT');
      expect(balanceIndex, lessThan(createIndex),
          reason: 'UPDATE_STOCK_BALANCE for the Received entity must run '
              'before CREATE_EVENT persists the (different) Shortfall '
              'Return entity, confirming the balance call is not '
              'accidentally the one paired with that CREATE_EVENT');
    });
  });

  group('Step 3a: upper hierarchy accepts a Shortfall Return (re-issue loop)',
      () {
    Map<String, dynamic> branch() => onAction.firstWhere(
          (a) => (conditionOf(a) ?? '') == "navigation.incomingStockEntryType == 'RETURNED'",
        );

    test('is gated purely on incomingStockEntryType == RETURNED', () {
      // This is the crux of the 3a/3b audit finding: this condition does not
      // also check formData.discrepancyReason != 'STOCK_DAMAGE', so it fires
      // for every accepted return regardless of reason - including the ones
      // meant to take the Stock-damage branch above it. That branch is dead
      // because the primary Accept confirmation (showAlertPopUp) never
      // collects a discrepancyReason in the first place (it has no `body`),
      // so formData.discrepancyReason is always unset on this path and the
      // 'STOCK_DAMAGE' branch's condition can never be true.
      expect(conditionOf(branch()),
          "navigation.incomingStockEntryType == 'RETURNED'");
    });

    test(
        'a re-issue shortfallTransaction is fetched (ISSUED, same quantity, '
        'sender/receiver swapped back) and followed by a CREATE_EVENT', () {
      final actions = actionsOf(branch());
      expectFetchFollowedByCreate(
        actions,
        'shortfallTransaction',
        reason: 'step 3a must persist the re-issue it builds - this is one '
            'of the two previously-fixed CREATE_EVENT omissions; guard '
            'against regressing it',
      );

      final fetch = actions.firstWhere((a) =>
          a['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
          a['properties']['configName'] == 'shortfallTransaction');

      expect(dataEntry(fetch, 'stockEntryType')['value'], 'ISSUED');
      expect(dataEntry(fetch, 'quantity')['value'], '{{navigation.quantity}}');
      expect(
        dataEntry(fetch, 'senderFacilityId')['value'],
        '{{fn:getUserFacilityId()}}',
        reason: 'the upper hierarchy (current user) re-issues the stock',
      );
      expect(
        dataEntry(fetch, 'receiverFacilityId')['value'],
        '{{navigation.senderFacilityId}}',
        reason: 'the re-issue is sent back down to the lower hierarchy',
      );
      expect(
        dataEntry(fetch, 'discrepancyReason')['value'],
        '{{formData.discrepancyReason}}',
        reason: 'the re-issue record should carry the discrepancy reason '
            'for audit purposes, matching the analogous step 2b '
            'shortfallTransaction fetch',
      );
    });

    test(
        'UPDATE_STOCK_BALANCE runs first in this branch, before entities is '
        'overwritten by the re-issue fetch', () {
      // This branch is preceded (outside its own "actions" array) by a
      // direct FETCH_TRANSFORMER_CONFIG(stockReceipt) that builds a
      // "received the return" entity (transactionType=RECEIVED,
      // qty=navigation.quantity) into contextData['entities']. This
      // UPDATE_STOCK_BALANCE must be the first action inside this branch so
      // it runs while entities still holds that entity, correctly crediting
      // the upper hierarchy with +quantity for receiving the return back,
      // before the FETCH_TRANSFORMER_CONFIG(shortfallTransaction) below
      // overwrites entities with the re-issue entity. The outer trailing
      // UPDATE_STOCK_BALANCE (shared across branches, after this
      // conditionalGroup) then applies the re-issue's -quantity effect,
      // netting to 0 for the upper hierarchy.
      final actions = actionsOf(branch());
      expect(actions.first['actionType'], 'UPDATE_STOCK_BALANCE',
          reason: 'UPDATE_STOCK_BALANCE must be the first action in this '
              'branch so it sees the pre-overwrite Received entity');

      final fetchIndex = actions.indexWhere((a) =>
          a['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
          a['properties']['configName'] == 'shortfallTransaction');
      expect(0, lessThan(fetchIndex),
          reason: 'the leading UPDATE_STOCK_BALANCE must run before the '
              're-issue shortfallTransaction fetch overwrites entities');
    });

    test('the branch appears before the generic RETURNED fallthrough', () {
      // Order matters: the STOCK_DAMAGE-gated branch, then this one, must be
      // evaluated before any later catch-all RETURNED handling.
      final index = onAction.indexOf(branch());
      final damageIndex = onAction.indexWhere((a) => (conditionOf(a) ?? '')
          .contains("formData.discrepancyReason == 'STOCK_DAMAGE'"));
      expect(damageIndex, greaterThanOrEqualTo(0),
          reason: 'expected a STOCK_DAMAGE-gated branch to exist (step 3b)');
      expect(damageIndex, lessThan(index),
          reason:
              'the Stock-damage branch must be checked before the generic '
              're-issue branch so damage can take priority when reachable');
    });
  });

  group('Step 3b: upper hierarchy accepts a Shortfall Return as Stock damage',
      () {
    Map<String, dynamic> branch() => onAction.firstWhere((a) =>
        (conditionOf(a) ?? '').contains("navigation.incomingStockEntryType == 'RETURNED'") &&
        (conditionOf(a) ?? '').contains("formData.discrepancyReason == 'STOCK_DAMAGE'"));

    test('condition checks both RETURNED and STOCK_DAMAGE reason', () {
      expect(
        conditionOf(branch()),
        "navigation.incomingStockEntryType == 'RETURNED' && formData.discrepancyReason == 'STOCK_DAMAGE'",
      );
    });

    test(
        'mutates the existing return record to DAMAGED/ACCEPTED in place - '
        'no new entity, no CREATE_EVENT', () {
      final actions = actionsOf(branch());

      final update = actions.firstWhere(
        (a) =>
            a['actionType'] == 'UPDATE_EVENT' &&
            a['properties']['source'] == 'existingModels',
      );
      expect(
        modifyEntry(update, 'StockModel.additionalFields.fields.stockEntryType')
            ['value'],
        'DAMAGED',
      );
      expect(
        modifyEntry(update, 'StockModel.additionalFields.fields.status')
            ['value'],
        'ACCEPTED',
      );

      expect(
        actions.any((a) => a['actionType'] == 'FETCH_TRANSFORMER_CONFIG'),
        isFalse,
        reason: 'no new transaction should be created for a damage write-off',
      );
      expect(
        actions.any((a) => a['actionType'] == 'CREATE_EVENT'),
        isFalse,
        reason: 'nothing new is persisted - only the existing record mutates',
      );
    });

    test('still runs UPDATE_STOCK_BALANCE so the damaged qty is marked in-hand',
        () {
      final actions = actionsOf(branch());
      expect(
        actions.any((a) => a['actionType'] == 'UPDATE_STOCK_BALANCE'),
        isTrue,
      );
    });
  });

  group(
      'Step 3c: upper hierarchy partial-accepts a Shortfall Return as Stock loss',
      () {
    Map<String, dynamic> branch() => onSecondaryAction.firstWhere((a) =>
        (conditionOf(a) ?? '').contains("navigation.incomingStockEntryType == 'RETURNED'") &&
        (conditionOf(a) ?? '').contains("formData.discrepancyReason == 'STOCK_LOSS'"));

    test('STOCK_LOSS is the only reason gating this terminal write-off', () {
      expect(
        conditionOf(branch()),
        "navigation.incomingStockEntryType == 'RETURNED' && formData.discrepancyReason == 'STOCK_LOSS'",
      );
    });

    test('record is zeroed out and marked ACCEPTED, nothing added to a balance',
        () {
      final actions = actionsOf(branch());
      final update = actions.firstWhere(
        (a) =>
            a['actionType'] == 'UPDATE_EVENT' &&
            a['properties']['source'] == 'existingModels',
      );

      expect(modifyEntry(update, 'StockModel.quantity')['value'], '0');
      expect(
        modifyEntry(update, 'StockModel.additionalFields.fields.status')
            ['value'],
        'ACCEPTED',
      );
      expect(
        modifyEntry(update,
            'StockModel.additionalFields.fields.actualQuantityReceived')
            ['value'],
        '0',
      );
      expect(modifyEntry(update, 'StockModel.transactionReason')['value'],
          'STOCK_LOSS');

      expect(
        actions.any((a) => a['actionType'] == 'UPDATE_STOCK_BALANCE'),
        isFalse,
        reason: 'a stock-loss write-off must not touch any balance',
      );
      expect(
        actions.any((a) => a['actionType'] == 'FETCH_TRANSFORMER_CONFIG'),
        isFalse,
        reason: 'terminal write-off - no follow-on transaction is created',
      );
      expect(
        actions.any((a) => a['actionType'] == 'CREATE_EVENT'),
        isFalse,
      );
    });

    test('is evaluated before the generic RETURNED-without-STOCK_LOSS guard',
        () {
      final lossIndex = onSecondaryAction.indexOf(branch());
      final genericReturnedIndex = onSecondaryAction.indexWhere((a) =>
          (conditionOf(a) ?? '') ==
          "navigation.incomingStockEntryType == 'RETURNED'");
      expect(genericReturnedIndex, greaterThanOrEqualTo(0),
          reason: 'expected a bare RETURNED guard branch (step 3d)');
      expect(lossIndex, lessThan(genericReturnedIndex),
          reason: 'STOCK_LOSS must be special-cased before the generic '
              'RETURNED rejection, or a valid write-off would be blocked');
    });
  });

  group('Step 3d: partial accept on a Shortfall Return with any other reason',
      () {
    Map<String, dynamic> branch() => onSecondaryAction.firstWhere(
          (a) =>
              (conditionOf(a) ?? '') ==
              "navigation.incomingStockEntryType == 'RETURNED'",
        );

    test('any RETURNED partial-accept not already caught by STOCK_LOSS is blocked',
        () {
      expect(conditionOf(branch()),
          "navigation.incomingStockEntryType == 'RETURNED'");
    });

    test('shows an explicit error toast with no side effects', () {
      final actions = actionsOf(branch());
      expect(actions.length, 1,
          reason: 'blocking branch should do nothing besides show the error');

      final toast = actions.single;
      expect(toast['actionType'], 'SHOW_TOAST');
      expect(
        toast['properties']['message'],
        'INVENTORY_PARTIAL_ACCEPT_RETURN_REQUIRES_STOCK_LOSS_REASON',
      );
      expect(toast['properties']['type'], 'error');
    });
  });

  test(
      'every shortfallTransaction FETCH_TRANSFORMER_CONFIG in onAction/onSecondaryAction '
      'is followed by a CREATE_EVENT (regression guard for the previously-fixed bug)',
      () {
    for (final branch in [...onAction, ...onSecondaryAction]) {
      final actions = (branch['actions'] as List?)?.cast<Map<String, dynamic>>();
      if (actions == null) continue;

      final fetchIndices = <int>[];
      for (var i = 0; i < actions.length; i++) {
        final action = actions[i];
        if (action['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
            action['properties']['configName'] == 'shortfallTransaction') {
          fetchIndices.add(i);
        }
      }
      for (final fetchIndex in fetchIndices) {
        final createIndex = actions.indexWhere(
          (a) => a['actionType'] == 'CREATE_EVENT',
          fetchIndex,
        );
        expect(createIndex, greaterThan(fetchIndex),
            reason:
                'a shortfallTransaction fetch at action index $fetchIndex in '
                'branch with condition ${conditionOf(branch)} is missing a '
                'following CREATE_EVENT - the built entity would never be '
                'persisted');
      }
    }
  });
}
