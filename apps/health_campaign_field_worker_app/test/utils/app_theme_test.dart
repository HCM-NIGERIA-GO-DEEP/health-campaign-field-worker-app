import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/app_theme.dart';

int _dependencyChanges = 0;

/// Reads the theme in build, like StockBalanceCard does.
class _ThemeReader extends StatefulWidget {
  const _ThemeReader();

  @override
  State<_ThemeReader> createState() => _ThemeReaderState();
}

class _ThemeReaderState extends State<_ThemeReader> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dependencyChanges++;
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return const SizedBox();
  }
}

void main() {
  testWidgets(
      'rebuilding MaterialApp with appLightTheme runs no theme animation '
      'and does not notify widgets that read the theme', (tester) async {
    // Same shape as app.dart: an outer builder rebuilds MaterialApp and reads
    // the theme again on every rebuild.
    final rebuild = ValueNotifier<int>(0);
    await tester.pumpWidget(ValueListenableBuilder<int>(
      valueListenable: rebuild,
      builder: (_, __, ___) =>
          MaterialApp(theme: appLightTheme, home: const _ThemeReader()),
    ));
    await tester.pumpAndSettle();
    _dependencyChanges = 0;

    rebuild.value++; // one LocalizationBloc state that rebuilds the app root
    await tester.pump();
    var extraFrames = 0;
    while (tester.binding.hasScheduledFrame && extraFrames < 50) {
      await tester.pump(const Duration(milliseconds: 16));
      extraFrames++;
    }

    expect(_dependencyChanges, 0);
    expect(extraFrames, 0, reason: 'a theme animation schedules more frames');
  });
}
