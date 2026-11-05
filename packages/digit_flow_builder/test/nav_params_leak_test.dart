import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// NavigationRegistry.navigateTo stores a screen's navigation params under TWO
/// keys - the bare screen name and "name::instanceId" (navigation_service.dart)
/// - but disposal only ever removed the composite one.
///
/// The bare entry therefore survived for the life of the process, and
/// navigation.* values from one run of a screen leaked into the next run of
/// that same screen. On device this showed up in the exitToHome probe as
/// navParamKeys growing with every completed flow and never shrinking:
///   [viewTransaction, incomingTransactions, stockReceiptDetails, stockSuccess]
///   [... , reportDetails]
///   [... , stockReconciliationDetails]
///
/// The removal is deliberately conditional. Two instances of one screen can
/// legitimately coexist (a flow re-entered before the first is torn down) and
/// the survivor still reads through the bare key as a fallback, so disposing
/// one instance must not pull the bare entry out from under the other.
void main() {
  final registry = FlowCrudStateRegistry();

  setUp(() {
    // Singleton: reset between tests so leakage from one cannot mask another.
    registry.disposeAll();
  });

  test('disposing the only instance removes the bare-name entry too', () {
    const screen = 'stockReceiptDetails';
    final composite = createCompositeKey(screen, 'inst-1');

    // Exactly what navigateTo does.
    registry.updateNavigationParams(screen, {'mrnNumber': 'AAAA'});
    registry.updateNavigationParams(composite, {'mrnNumber': 'AAAA'});

    expect(registry.debugNavParamKeys, containsAll([screen, composite]));

    registry.disposeByCompositeKey(composite);

    expect(registry.debugNavParamKeys, isNot(contains(composite)));
    expect(registry.debugNavParamKeys, isNot(contains(screen)),
        reason: 'the bare-name entry leaked - its values will bleed into the '
            'next run of this screen');
  });

  test('a surviving second instance keeps the bare-name entry', () {
    // The case that makes unconditional removal wrong.
    const screen = 'householdOverview';
    final first = createCompositeKey(screen, 'inst-1');
    final second = createCompositeKey(screen, 'inst-2');

    registry.updateNavigationParams(screen, {'householdId': 'h2'});
    registry.updateNavigationParams(first, {'householdId': 'h1'});
    registry.updateNavigationParams(second, {'householdId': 'h2'});

    registry.disposeByCompositeKey(first);

    expect(registry.debugNavParamKeys, isNot(contains(first)));
    expect(registry.debugNavParamKeys, contains(second));
    expect(registry.debugNavParamKeys, contains(screen),
        reason: 'the surviving instance still falls back to the bare key');
  });

  test('disposing the last of several instances finally clears it', () {
    const screen = 'searchBeneficiary';
    final first = createCompositeKey(screen, 'inst-1');
    final second = createCompositeKey(screen, 'inst-2');

    registry.updateNavigationParams(screen, {'q': 'x'});
    registry.updateNavigationParams(first, {'q': 'x'});
    registry.updateNavigationParams(second, {'q': 'y'});

    registry.disposeByCompositeKey(first);
    expect(registry.debugNavParamKeys, contains(screen));

    registry.disposeByCompositeKey(second);
    expect(registry.debugNavParamKeys, isNot(contains(screen)),
        reason: 'nothing is left to read the bare key, so it must go');
  });

  test('one screen\'s disposal never touches another screen', () {
    final a = createCompositeKey('screenA', 'i1');
    final b = createCompositeKey('screenB', 'i1');

    registry.updateNavigationParams('screenA', {'k': 'a'});
    registry.updateNavigationParams(a, {'k': 'a'});
    registry.updateNavigationParams('screenB', {'k': 'b'});
    registry.updateNavigationParams(b, {'k': 'b'});

    registry.disposeByCompositeKey(a);

    expect(registry.debugNavParamKeys, containsAll(['screenB', b]));
  });

  test('a prefix-sharing screen name is not mistaken for an instance', () {
    // "search" and "searchBeneficiary" both start with "search"; the guard
    // must match on the "::" boundary, not a bare prefix, or disposing one
    // would be blocked forever by the other.
    final search = createCompositeKey('search', 'i1');

    registry.updateNavigationParams('search', {'k': 'v'});
    registry.updateNavigationParams(search, {'k': 'v'});
    registry.updateNavigationParams('searchBeneficiary', {'k': 'other'});
    registry.updateNavigationParams(
        createCompositeKey('searchBeneficiary', 'i1'), {'k': 'other'});

    registry.disposeByCompositeKey(search);

    expect(registry.debugNavParamKeys, isNot(contains('search')),
        reason: 'searchBeneficiary::i1 is a different screen and must not '
            'keep "search" alive');
    expect(registry.debugNavParamKeys, contains('searchBeneficiary'));
  });

  test('repeated run/dispose cycles do not accumulate keys', () {
    // The user-visible symptom: navParamKeys grew with every flow.
    const screen = 'deliverySuccess';

    for (var i = 0; i < 5; i++) {
      final composite = createCompositeKey(screen, 'inst-$i');
      registry.updateNavigationParams(screen, {'run': i});
      registry.updateNavigationParams(composite, {'run': i});
      registry.disposeByCompositeKey(composite);
    }

    expect(registry.debugNavParamKeys, isEmpty,
        reason: 'five completed flows left ${registry.debugNavParamKeys} '
            'behind');
  });
}
