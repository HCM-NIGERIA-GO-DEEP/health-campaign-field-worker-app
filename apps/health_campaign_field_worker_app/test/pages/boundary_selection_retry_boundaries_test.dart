import 'dart:io';

import 'package:digit_data_model/data_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Liberia QA: "Failed to check data in server", tried multiple times.
///
/// Submit checks the server for `effectiveSelectedBoundaries`. The Retry
/// button of the "unable to check" dialog was given
/// `selectedLastLevelBoundaries`, which is empty whenever the last level is a
/// single-select dropdown. Retry then asked the server about no boundary.
void main() {
  test('a single-select last level leaves selectedLastLevelBoundaries empty',
      () {
    final district = BoundaryModel(code: 'LR_GBEAPO', label: 'District');
    final state = BoundaryState(selectedBoundaryMap: {'District': district});

    expect(state.selectedLastLevelBoundaries, isEmpty);
    expect(state.effectiveSelectedBoundaries.map((b) => b.code), ['LR_GBEAPO']);
  });

  test('every download dialog on the boundary page gets the same boundaries',
      () {
    final source = File('lib/pages/boundary_selection.dart').readAsStringSync();
    final passed = RegExp(r'boundaries:\s*state\s*\.\s*(\w+)')
        .allMatches(source)
        .map((m) => m.group(1))
        .toList();

    expect(passed, isNotEmpty);
    expect(passed.toSet(), {'effectiveSelectedBoundaries'},
        reason: 'Retry must check what Submit checked');
  });
}
