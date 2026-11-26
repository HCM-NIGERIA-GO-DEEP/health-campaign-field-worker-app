import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart';
import 'package:health_campaign_field_worker_app/widgets/stock_reconciliation/stock_reconciliation_manual_count.dart';
import 'package:reactive_forms/reactive_forms.dart';

void main() {
  testWidgets('warehouse manual count prefill and edits use integer pieces',
      (tester) async {
    final control = FormControl<int>(
      value: 75,
      validators: [Validators.required, Validators.max(10000000)],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReactiveTextField<int>(
          formControl: control,
          valueAccessor: StockReconciliationCountAccessor(inBales: true),
        ),
      ),
    ));
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).controller?.text, '1.5');

    await tester.enterText(field, '2.02');
    expect(control.value, 101);
    expect(control.valid, isTrue);

    await tester.enterText(field, '2.01');
    expect(control.value, isNull);
    expect(control.valid, isFalse);

    await tester.enterText(field, '200000.02');
    expect(control.value, 10000001);
    expect(control.valid, isFalse);

    control.updateValue(1);
    await tester.pump();
    expect(tester.widget<TextField>(field).controller?.text, '0.02');
  });

  test('Distributor takes precedence for display and retains pieces', () {
    for (final roles in [
      ['DISTRIBUTOR'],
      ['WAREHOUSE_MANAGER', 'DISTRIBUTOR'],
    ]) {
      final unit = stockDisplayUnitForRoles(roles);
      expect(unit, 'PIECES');
      final accessor =
          StockReconciliationCountAccessor(inBales: unit == 'BALES');
      expect(accessor.viewToModelValue('75'), 75);
      expect(accessor.modelToViewValue(75), '75');
    }
  });
}
