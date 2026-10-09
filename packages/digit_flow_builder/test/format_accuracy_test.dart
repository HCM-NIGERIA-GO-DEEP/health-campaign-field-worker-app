import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The GPS capture widget shows accuracy as toStringAsFixed(2) but persists the
/// raw double, so any screen reading the stored value back through a template
/// printed the full precision instead - the closed-household summary and
/// preview rendered "4.7299999999999995" where capture had shown "4.73".
void main() {
  setUpAll(initializeFunctionRegistry);

  dynamic call(List<dynamic> args) =>
      FunctionRegistry.call('formatAccuracy', args, CrudStateData(const {}, const []));

  test('is registered at all', () {
    expect(FunctionRegistry.call('formatAccuracy', [1.0], CrudStateData(const {}, const [])),
        isNotNull);
  });

  test('rounds a raw double to two decimals', () {
    expect(call([4.7299999999999995]), '4.73');
  });

  test('rounds the string a template resolves to', () {
    // resolveValueRaw stringifies before the function receives it.
    expect(call(['12.345678']), '12.35');
  });

  test('pads a value that has fewer than two decimals', () {
    expect(call([8]), '8.00');
  });

  test('honours an explicit precision argument', () {
    expect(call([4.7299999999999995, 3]), '4.730');
  });

  test('renders the literal "null" an unresolved placeholder leaves behind',
      () {
    // resolveTemplate substitutes the string "null" for a null placeholder, so
    // a plain null check is not enough to catch a missing reading.
    expect(call(['null']), '--');
  });

  test('renders a missing or non-numeric reading as "--"', () {
    expect(call([null]), '--');
    expect(call([]), '--');
    expect(call(['']), '--');
    expect(call(['not a number']), '--');
  });
}
