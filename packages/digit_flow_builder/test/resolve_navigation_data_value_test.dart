import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers a bug in the ISSUE/RETURN "view transaction" heading on the stock
/// acknowledgement flow (manage_stock.dart): a NAVIGATION action's `data`
/// template `{{fn:getViewTransactionHeadingCode(navigation.stockEntryType)}}`
/// always resolved to the generic receipt-details heading, regardless of the
/// actual transaction type.
///
/// Root cause: `resolveNavigationDataValue` only preferred `contextData` as
/// the first resolution source when the raw template literally contained
/// "contextData.". A template referencing `navigation.*` (including nested
/// inside an `fn:(...)` call) fell through to `stateFormData` first instead -
/// which never carries a `navigation` key - so the function received a `null`
/// argument and returned its own non-null default. That default satisfied
/// neither of the "retry against the other source" conditions (`== null` or
/// `== rawValue`), so the correct value living in `contextData['navigation']`
/// was never reached.
void main() {
  setUpAll(() {
    // Mirrors getViewTransactionHeadingCode's shape (function_registries.dart
    // in the app) without depending on the app package: maps a known
    // stockEntryType to its own heading, defaulting to a generic one when the
    // input is missing/unmapped - exactly the shape that lets a null arg
    // "succeed" with a wrong-but-non-null value.
    FunctionRegistry.register('testHeadingFn', (args, stateData) {
      final stockEntryType = args.isNotEmpty
          ? args.first?.toString().toUpperCase() ?? ''
          : '';
      const headings = {
        'ISSUED': 'STOCK_ISSUE_DETAILS_HEADING',
        'RETURNED': 'STOCK_RETURN_DETAILS_HEADING',
      };
      return headings[stockEntryType] ?? 'STOCK_RECEIPT_DETAILS_HEADING';
    });
  });

  test(
      'a navigation.* argument nested inside fn:(...) resolves against contextData, not the unrelated stateFormData',
      () {
    // stateFormData is the CURRENT screen's own form fields - it never has a
    // navigation key, matching real behavior (e.g. stockDetails/
    // warehouseDetails fields on the RECORDSTOCK form).
    final stateFormData = <String, dynamic>{
      'stockDetails': {'facilityFromWhich': 'WAREHOUSE-1'},
    };

    final contextData = <String, dynamic>{
      'navigation': {'stockEntryType': 'RETURNED'},
      'formData': stateFormData,
    };

    final resolved = resolveNavigationDataValue(
      rawValue: '{{fn:testHeadingFn(navigation.stockEntryType)}}',
      stateFormData: stateFormData,
      contextData: contextData,
    );

    expect(resolved, 'STOCK_RETURN_DETAILS_HEADING');
  });

  test('the same template resolves correctly for ISSUED too', () {
    final stateFormData = <String, dynamic>{};
    final contextData = <String, dynamic>{
      'navigation': {'stockEntryType': 'ISSUED'},
      'formData': stateFormData,
    };

    final resolved = resolveNavigationDataValue(
      rawValue: '{{fn:testHeadingFn(navigation.stockEntryType)}}',
      stateFormData: stateFormData,
      contextData: contextData,
    );

    expect(resolved, 'STOCK_ISSUE_DETAILS_HEADING');
  });

  test(
      'a plain (non-fn) navigation.* template still resolves against contextData',
      () {
    final stateFormData = <String, dynamic>{};
    final contextData = <String, dynamic>{
      'navigation': {'mrnNumber': 'MRN-123'},
      'formData': stateFormData,
    };

    final resolved = resolveNavigationDataValue(
      rawValue: '{{navigation.mrnNumber}}',
      stateFormData: stateFormData,
      contextData: contextData,
    );

    expect(resolved, 'MRN-123');
  });

  test(
      'a template mixing navigation.* and formData.* in one fn: call still resolves both from contextData',
      () {
    // Mirrors manage_stock.dart's
    // {{fn:subtractQuantity(navigation.quantity, formData.actualQuantityReceived)}}.
    FunctionRegistry.register('testSubtract', (args, stateData) {
      final a = num.tryParse(args[0]?.toString() ?? '') ?? 0;
      final b = num.tryParse(args[1]?.toString() ?? '') ?? 0;
      return (a - b).toString();
    });

    final stateFormData = <String, dynamic>{
      'stockReceiptDetails': {'actualQuantityReceived': '30'},
    };
    final contextData = <String, dynamic>{
      'navigation': {'quantity': '50'},
      'formData': {'actualQuantityReceived': '30'},
    };

    final resolved = resolveNavigationDataValue(
      rawValue:
          '{{fn:testSubtract(navigation.quantity, formData.actualQuantityReceived)}}',
      stateFormData: stateFormData,
      contextData: contextData,
    );

    expect(resolved, '20');
  });
}
