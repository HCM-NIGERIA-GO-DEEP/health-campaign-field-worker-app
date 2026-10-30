// RC-02 (mechanism): the registry maps a bare screen key to the NEWEST
// registered instance, and disposing an instance never rewinds that map.
//
// Production change that would flip these assertions: `disposeByCompositeKey`
// (flow_crud_bloc.dart:527-529) removing the `_instanceIds` entry when it
// disposes the current owner, or header/footer widgets being mapped with the
// composite key (layout_renderer.dart:448-485).
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/unique_id_test_support.dart';

void main() {
  setUp(resetRegistry);
  tearDown(resetRegistry);

  test('a bare key write lands in the newest instance slot', () {
    final reg = FlowCrudStateRegistry();
    reg.registerInstance(kScreen, 'S1');
    reg.update(kScreen, const FlowCrudState(widgetData: {'searchBar': 'ab'}));

    expect(
      reg.getByCompositeKey('searchBeneficiary::S1')!.widgetData!['searchBar'],
      'ab',
    );
    // Nothing is stored under the bare key itself (flow_crud_bloc.dart:649-655).
    expect(reg.getByCompositeKey(kScreen), isNull);

    // Registering a second instance redirects the bare key at once.
    reg.registerInstance(kScreen, 'S2');
    expect(reg.get(kScreen), isNull, reason: 'S2 has no state yet');
    expect(
      reg.getByCompositeKey('searchBeneficiary::S1')!.widgetData!['searchBar'],
      'ab',
      reason: 'S1 keeps its own slot',
    );
  });

  test('disposing the newest instance leaves the bare key pointing at it', () {
    final reg = FlowCrudStateRegistry();
    reg.registerInstance(kScreen, 'S1');
    reg.update(kScreen, const FlowCrudState(widgetData: {'searchBar': 'ab'}));
    reg.registerInstance(kScreen, 'S2');
    reg.update(
      'searchBeneficiary::S2',
      const FlowCrudState(widgetData: {'searchBar': 'zz'}),
    );

    // What FlowBuilderHomePage.dispose does (flow_builder_home_page.dart:88).
    reg.disposeByCompositeKey('searchBeneficiary::S2');

    expect(reg.getInstanceId(kScreen), 'S2', reason: 'owner is never rewound');
    expect(reg.get(kScreen), isNull, reason: 'bare reads hit the removed slot');
    expect(
      reg.getByCompositeKey('searchBeneficiary::S1')!.widgetData!['searchBar'],
      'ab',
      reason: 'the older instance still has its data, but nobody reads it',
    );

    // listen() re-creates an empty slot under the disposed key (657-662).
    final zombie = reg.listen(kScreen);
    expect(zombie.value, isNull);
    expect(
      identical(zombie, reg.listenByCompositeKey('searchBeneficiary::S2')),
      isTrue,
    );

    // A later bare write lands on the disposed instance, not on S1.
    reg.update(kScreen, const FlowCrudState(widgetData: {'searchBar': 'new'}));
    expect(
      reg.getByCompositeKey('searchBeneficiary::S2')!.widgetData!['searchBar'],
      'new',
    );
    expect(
      reg.getByCompositeKey('searchBeneficiary::S1')!.widgetData!['searchBar'],
      'ab',
    );
  });

  test('negative control: disposeIfOwner would rewind, but has no callers', () {
    final reg = FlowCrudStateRegistry();
    reg.registerInstance(kScreen, 'S1');
    reg.update(kScreen, const FlowCrudState(widgetData: {'searchBar': 'ab'}));
    reg.registerInstance(kScreen, 'S2');
    reg.update(
      'searchBeneficiary::S2',
      const FlowCrudState(widgetData: {'searchBar': 'zz'}),
    );

    expect(reg.disposeIfOwner(kScreen, 'S2'), isTrue);
    expect(reg.getInstanceId(kScreen), isNull);
    expect(
      reg.getByCompositeKey('searchBeneficiary::S1')!.widgetData!['searchBar'],
      'ab',
    );
  });
}
