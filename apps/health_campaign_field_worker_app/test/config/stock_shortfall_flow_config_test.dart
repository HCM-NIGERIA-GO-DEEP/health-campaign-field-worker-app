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
///   The discrepancy reason is chosen by the LOWER hierarchy at step 2b, not
///   re-entered by the upper hierarchy - it's carried down to the upper
///   hierarchy's incoming-transactions list as part of the return record's
///   own additionalFields, and threaded into navigation.discrepancyReason
///   when they open it. Accept (onAction) auto-resolves based on that
///   already-known reason; there is nothing left for Partially Accept to do
///   on a return, since no new input is collected.
///   3a. Accepting an incoming Shortfall Return whose reason is In-transit/
///       Miscount/anything other than Stock damage or Stock loss: a new
///       re-issue shortfallTransaction is created (stockEntryType ISSUED,
///       same quantity, sender/receiver swapped back), looping into step 2
///       for the lower hierarchy again.
///   3b. Accepting a return whose reason is Stock damage: no new transaction
///       - the existing return record is mutated in place to stockEntryType
///       DAMAGED, ACCEPTED.
///   3c. Accepting a return whose reason is Stock Loss: the record is zeroed
///       out (quantity 0) and ACCEPTED - a terminal write-off, nothing added
///       to any balance.
///   3d. Tapping Partially Accept on any return (regardless of reason) is
///       blocked with an explicit error directing to Accept instead, since
///       resolution never depends on anything typed in that popup.
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
      // The more specific STOCK_DAMAGE and STOCK_LOSS branches are checked
      // first (consecutive conditional group, first match wins), so this
      // bare RETURNED condition only ever fires once those two have already
      // been ruled out - it's the correct catch-all for every other reason.
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
        '{{navigation.discrepancyReason}}',
        reason: 'the re-issue record should carry forward the discrepancy '
            'reason the lower hierarchy originally gave, for audit purposes',
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

    test(
        'a second UPDATE_STOCK_BALANCE after CREATE_EVENT applies the '
        're-issue\'s own -quantity effect, scoped to this branch', () {
      // Regression guard: this branch used to rely on a single
      // UPDATE_STOCK_BALANCE shared AFTER the whole conditional group
      // (DAMAGE/LOSS/RETURNED) to net the re-issue's -quantity. Since that
      // shared call ran unconditionally regardless of which branch matched,
      // it also fired for DAMAGE/LOSS - which never touch
      // contextData['entities'] - wrongly crediting them with the +quantity
      // entity still left over from the top of onAction. Each branch must
      // now own its complete balance effect.
      final actions = actionsOf(branch());
      final updateStockBalanceCount = actions
          .where((a) => a['actionType'] == 'UPDATE_STOCK_BALANCE')
          .length;
      expect(updateStockBalanceCount, 2,
          reason: 'one UPDATE_STOCK_BALANCE for the +quantity receive, one '
              'for the re-issue\'s own -quantity - this branch must not '
              'depend on a balance call shared with other branches');
      expect(actions.last['actionType'], 'UPDATE_STOCK_BALANCE',
          reason: 'the second UPDATE_STOCK_BALANCE must run after '
              'CREATE_EVENT, once entities holds the just-created re-issue');
    });

    test('the branch appears after the STOCK_DAMAGE and STOCK_LOSS branches',
        () {
      // Order matters: the more specific branches must be evaluated before
      // this catch-all, since they're all part of one consecutive
      // conditional group (first match wins).
      final index = onAction.indexOf(branch());
      final damageIndex = onAction.indexWhere((a) => (conditionOf(a) ?? '')
          .contains("navigation.discrepancyReason == 'STOCK_DAMAGE'"));
      final lossIndex = onAction.indexWhere((a) => (conditionOf(a) ?? '')
          .contains("navigation.discrepancyReason == 'STOCK_LOSS'"));
      expect(damageIndex, greaterThanOrEqualTo(0),
          reason: 'expected a STOCK_DAMAGE-gated branch to exist (step 3b)');
      expect(lossIndex, greaterThanOrEqualTo(0),
          reason: 'expected a STOCK_LOSS-gated branch to exist (step 3c)');
      expect(damageIndex, lessThan(index),
          reason:
              'the Stock-damage branch must be checked before the generic '
              're-issue branch so damage can take priority when reachable');
      expect(lossIndex, lessThan(index),
          reason: 'the Stock-loss branch must be checked before the generic '
              're-issue branch so loss can take priority when reachable');
    });
  });

  group('Step 3b: upper hierarchy accepts a Shortfall Return as Stock damage',
      () {
    Map<String, dynamic> branch() => onAction.firstWhere((a) =>
        (conditionOf(a) ?? '').contains("navigation.incomingStockEntryType == 'RETURNED'") &&
        (conditionOf(a) ?? '').contains("navigation.discrepancyReason == 'STOCK_DAMAGE'"));

    test('condition checks both RETURNED and STOCK_DAMAGE reason', () {
      expect(
        conditionOf(branch()),
        "navigation.incomingStockEntryType == 'RETURNED' && navigation.discrepancyReason == 'STOCK_DAMAGE'",
      );
    });

    test(
        'mutates the existing return record to DAMAGED/ACCEPTED and zeroes '
        'the quantity in place - no new entity, no CREATE_EVENT', () {
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
      expect(modifyEntry(update, 'StockModel.quantity')['value'], '0');
      expect(
        modifyEntry(update,
            'StockModel.additionalFields.fields.actualQuantityReceived')
            ['value'],
        '0',
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

    test(
        'does not run UPDATE_STOCK_BALANCE - stock damage is a terminal '
        'write-off just like stock loss, it must not increase the upper '
        'hierarchy balance', () {
      final actions = actionsOf(branch());
      expect(
        actions.any((a) => a['actionType'] == 'UPDATE_STOCK_BALANCE'),
        isFalse,
      );
    });
  });

  group(
      'Step 3c: upper hierarchy accepts a Shortfall Return as Stock loss',
      () {
    Map<String, dynamic> branch() => onAction.firstWhere((a) =>
        (conditionOf(a) ?? '').contains("navigation.incomingStockEntryType == 'RETURNED'") &&
        (conditionOf(a) ?? '').contains("navigation.discrepancyReason == 'STOCK_LOSS'"));

    test('STOCK_LOSS is the only reason gating this terminal write-off', () {
      expect(
        conditionOf(branch()),
        "navigation.incomingStockEntryType == 'RETURNED' && navigation.discrepancyReason == 'STOCK_LOSS'",
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

    test('is evaluated before the generic re-issue catch-all in onAction',
        () {
      final lossIndex = onAction.indexOf(branch());
      final genericReturnedIndex = onAction.indexWhere((a) =>
          (conditionOf(a) ?? '') ==
          "navigation.incomingStockEntryType == 'RETURNED'");
      expect(genericReturnedIndex, greaterThanOrEqualTo(0),
          reason: 'expected a bare RETURNED catch-all branch (step 3a)');
      expect(lossIndex, lessThan(genericReturnedIndex),
          reason: 'STOCK_LOSS must be special-cased before the generic '
              're-issue branch, or a valid write-off would re-issue instead');
    });
  });

  group('Step 3d: Partially Accept on any Shortfall Return is blocked',
      () {
    Map<String, dynamic> branch() => onSecondaryAction.firstWhere(
          (a) =>
              (conditionOf(a) ?? '') ==
              "navigation.incomingStockEntryType == 'RETURNED'",
        );

    test('every RETURNED partial-accept attempt is blocked, regardless of reason',
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
        'INVENTORY_RETURN_RESOLVED_VIA_ACCEPT',
      );
      expect(toast['properties']['type'], 'error');
    });

    test('this is the first branch in onSecondaryAction (runs before the '
        'generic fresh-dispatch partial-accept guards)', () {
      expect(onSecondaryAction.first, same(branch()));
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

  group(
      'Step 3e (plain Accept, no Shortfall Return involved) credits the '
      'full dispatched quantity exactly once', () {
    Map<String, dynamic> branch() =>
        onAction.firstWhere((a) => conditionOf(a) == 'DEFAULT');

    test(
        'a DEFAULT branch exists in onAction\'s conditional group and only '
        'runs UPDATE_STOCK_BALANCE', () {
      // Regression guard: before this branch existed, a plain accept (no
      // incomingStockEntryType=='RETURNED' at all) relied on the SAME shared
      // trailing UPDATE_STOCK_BALANCE that also, incorrectly, fired for
      // DAMAGE/LOSS. That shared call has been removed - the DEFAULT branch
      // now owns the plain-accept credit explicitly, using the
      // "stockReceipt" entity built at the very top of onAction (untouched
      // by DAMAGE/LOSS/RETURNED, since none of those branches match here).
      final actions = actionsOf(branch());
      expect(actions.map((a) => a['actionType']).toList(),
          ['UPDATE_STOCK_BALANCE']);
    });

    test(
        'no bare UPDATE_STOCK_BALANCE action remains shared after the whole '
        'conditional group', () {
      // The DAMAGE, STOCK_LOSS, generic RETURNED, and DEFAULT branches above
      // must be the last four entries with a 'condition' key before the
      // trailing (unconditional) stockSuccess NAVIGATION - there must be no
      // standalone UPDATE_STOCK_BALANCE action sitting between the
      // conditional group and that NAVIGATION, since such a call would run
      // for every branch regardless of which one matched (this is exactly
      // the bug that wrongly credited DAMAGE/LOSS).
      final conditionalIndices = <int>[];
      for (var i = 0; i < onAction.length; i++) {
        if (onAction[i]['condition'] != null) conditionalIndices.add(i);
      }
      final lastConditionalIndex = conditionalIndices.last;
      final afterGroup = onAction.sublist(lastConditionalIndex + 1);
      expect(
        afterGroup.any((a) => a['actionType'] == 'UPDATE_STOCK_BALANCE'),
        isFalse,
        reason: 'found a bare UPDATE_STOCK_BALANCE after the conditional '
            'group - it would run unconditionally for every branch '
            '(including DAMAGE/LOSS, which must have zero balance impact)',
      );
    });
  });
}
