import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart';

/// Guards the ITN entitlement shown as NUMBER_OF_ITN_FOR_DELIVERY.
///
/// This used to be computed in the app as "1 net per 2 household members,
/// capped at 3". That cap was app-side guesswork: the per-household maximum
/// is a per-district campaign decision carried on the project type, and each
/// district is its own project. The constant silently overrode the config, so
/// a district configured for 4 nets still issued 3. The figure now comes
/// straight from the resolved dose criteria and the app imposes no ceiling of
/// its own.
void main() {
  group('maxDeliveryQuantityFromDoseCriteria', () {
    test('returns the configured quantity verbatim, uncapped', () {
      // The case the old hardcoded 3 broke: a district configured for 4.
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          {
            'ProductVariants': [
              {'productVariantId': 'pv-1', 'quantity': 4}
            ]
          }
        ]),
        4,
      );
    });

    test('takes the largest quantity across eligible variants', () {
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          {
            'ProductVariants': [
              {'quantity': 2}
            ]
          },
          {
            'ProductVariants': [
              {'quantity': 5},
              {'quantity': 3}
            ]
          }
        ]),
        5,
      );
    });

    test('parses a quantity sent as a string or a double', () {
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          {
            'ProductVariants': [
              {'quantity': '4'}
            ]
          }
        ]),
        4,
      );
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          {
            'ProductVariants': [
              {'quantity': 2.0}
            ]
          }
        ]),
        2,
      );
    });

    test('accepts a single criterion passed as a bare map', () {
      expect(
        maxDeliveryQuantityFromDoseCriteria({
          'ProductVariants': [
            {'quantity': 3}
          ]
        }),
        3,
      );
    });

    test('nothing configured yields null, not zero', () {
      // A blank is honest; "0 nets" would be a misleading instruction.
      expect(maxDeliveryQuantityFromDoseCriteria(null), isNull);
      expect(maxDeliveryQuantityFromDoseCriteria(const []), isNull);
      expect(maxDeliveryQuantityFromDoseCriteria('not a list'), isNull);
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          {'ProductVariants': []}
        ]),
        isNull,
      );
    });

    test('skips malformed entries instead of throwing', () {
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          'junk',
          {'ProductVariants': 'not a list'},
          {
            'ProductVariants': [
              'junk',
              {'quantity': null},
              {'quantity': 'abc'},
              {'quantity': 0},
              {'quantity': -2},
              {'quantity': 4},
            ]
          },
        ]),
        4,
      );
    });
  });
}
