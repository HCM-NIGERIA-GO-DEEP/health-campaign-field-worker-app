import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart';

/// Covers maxDeliveryQuantityFromDoseCriteria, which resolves the
/// per-household ITN maximum from the project's backend configuration.
///
/// This replaced an app-side `maxDeliveryQuantityPerHousehold = 3` constant.
/// That constant silently clamped whatever the campaign configured, so a
/// campaign created with a maximum of 4 still distributed only 3. The maximum
/// is a per-district decision (2 nets in the four urban Monrovia districts, 4
/// elsewhere) and each district is its own project with its own project type,
/// so the only correct source is the dose criteria the backend sends.
///
/// The resolved value reaches the field worker through ResourceCard's
/// max-quantity bound, its pre-filled initial value and its Validators.max
/// (widgets/resource_card/custom_resource_card.dart).
void main() {
  Map<String, dynamic> criterion(List<int?> quantities) => {
        'ProductVariants': [
          for (final q in quantities)
            {'productVariantId': 'PVAR-1', 'quantity': q},
        ],
      };

  group('maxDeliveryQuantityFromDoseCriteria', () {
    test('returns the configured quantity verbatim - it is not capped', () {
      // The whole point of the change: 4 must survive as 4.
      expect(maxDeliveryQuantityFromDoseCriteria([criterion([4])]), 4);
      expect(maxDeliveryQuantityFromDoseCriteria([criterion([2])]), 2);
      expect(maxDeliveryQuantityFromDoseCriteria([criterion([10])]), 10);
    });

    test('an urban district configured for 2 is not raised to a default', () {
      expect(maxDeliveryQuantityFromDoseCriteria([criterion([2])]), 2);
    });

    test('takes the largest quantity across eligible variants', () {
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          criterion([2]),
          criterion([4]),
        ]),
        4,
      );
      expect(maxDeliveryQuantityFromDoseCriteria([criterion([1, 4, 3])]), 4);
    });

    test('accepts a single criterion passed as a bare map', () {
      expect(maxDeliveryQuantityFromDoseCriteria(criterion([4])), 4);
    });

    test('parses a quantity sent as a string or a double', () {
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          {
            'ProductVariants': [
              {'quantity': '4'},
            ],
          }
        ]),
        4,
      );
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          {
            'ProductVariants': [
              {'quantity': 4.0},
            ],
          }
        ]),
        4,
      );
    });

    test('yields null when nothing usable is configured, not zero', () {
      // A blank is honest; "0 nets" would be a misleading instruction.
      expect(maxDeliveryQuantityFromDoseCriteria(null), isNull);
      expect(maxDeliveryQuantityFromDoseCriteria(const []), isNull);
      expect(maxDeliveryQuantityFromDoseCriteria([criterion([0])]), isNull);
      expect(maxDeliveryQuantityFromDoseCriteria([criterion([null])]), isNull);
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          {'ProductVariants': 'not-a-list'}
        ]),
        isNull,
      );
    });

    test('ignores malformed entries instead of throwing', () {
      expect(
        maxDeliveryQuantityFromDoseCriteria([
          'garbage',
          null,
          criterion([4]),
        ]),
        4,
      );
    });
  });
}
