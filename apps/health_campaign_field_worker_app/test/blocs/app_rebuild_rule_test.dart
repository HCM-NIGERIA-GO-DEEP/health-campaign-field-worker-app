import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/blocs/localization/app_rebuild_rule.dart';

void main() {
  group('shouldRebuildAppForLocalization', () {
    test('a load that starts does not rebuild the app', () {
      expect(
        shouldRebuildAppForLocalization(
          previousIndex: 0,
          currentIndex: 0,
          previousLoading: false,
          currentLoading: true,
        ),
        isFalse,
      );
    });

    test('a load that ends (done or failed) rebuilds the app', () {
      // Done: loading false + isLocalizationLoadCompleted. Failed: loading
      // false + retryModule. Both must refresh the package text lists.
      expect(
        shouldRebuildAppForLocalization(
          previousIndex: 0,
          currentIndex: 0,
          previousLoading: true,
          currentLoading: false,
        ),
        isTrue,
      );
    });

    test('a language change rebuilds the app', () {
      expect(
        shouldRebuildAppForLocalization(
          previousIndex: 0,
          currentIndex: 1,
          previousLoading: false,
          currentLoading: false,
        ),
        isTrue,
      );
    });

    test('a language change during a load still rebuilds the app', () {
      expect(
        shouldRebuildAppForLocalization(
          previousIndex: 1,
          currentIndex: 0,
          previousLoading: false,
          currentLoading: true,
        ),
        isTrue,
      );
    });

    test('an unrelated idle state does not rebuild the app', () {
      expect(
        shouldRebuildAppForLocalization(
          previousIndex: 0,
          currentIndex: 0,
          previousLoading: false,
          currentLoading: false,
        ),
        isFalse,
      );
    });

    test('one card tap (loading, then done) rebuilds the app once', () {
      final transitions = [(false, true), (true, false), (false, false)];
      final rebuilds = transitions
          .where((state) => shouldRebuildAppForLocalization(
                previousIndex: 0,
                currentIndex: 0,
                previousLoading: state.$1,
                currentLoading: state.$2,
              ))
          .length;
      expect(rebuilds, 1);
    });
  });
}
