import 'package:digit_data_model/models/entities/product_variant.dart';

import 'constants.dart';

/// Typical delivery-team synthetic ids used in inventory flows.
bool isInventoryDeliveryTeamCode(String? code) {
  if (code == null || code.isEmpty) return false;
  final c = code.trim();
  return c == 'DELIVERY_TEAM' ||
      c == 'Delivery Team' ||
      c.startsWith('DELIVERY');
}

/// LGA-side storing facility usage → Bednet-only products (SKU / variation text).
bool isUsageLgaSide(String? usage) {
  final u = (usage ?? '').trim();
  if (u.isEmpty) return false;
  if (u == Constants.districtFacility || u == Constants.lgaFacility) return true;
  final lower = u.toLowerCase();
  return lower.contains('lga') && !lower.contains('health');
}

/// Health facility usage → products whose SKU/variation contains SPAQ.
bool isUsageHealthFacility(String? usage) {
  final u = (usage ?? '').trim();
  if (u.isEmpty) return false;
  if (u == Constants.healthFacility) return true;
  final lower = u.toLowerCase();
  return lower.contains('health facility') ||
      (lower.contains('health') && lower.contains('facility'));
}

bool matchesBednetProduct(ProductVariantModel p) {
  final sku = (p.sku ?? '').toLowerCase();
  final variation = (p.variation ?? '').toLowerCase();
  return sku.contains('bednet') || variation.contains('bednet');
}

bool matchesSpaqProduct(ProductVariantModel p) {
  final sku = (p.sku ?? '').toLowerCase();
  final variation = (p.variation ?? '').toLowerCase();
  return sku.contains('spaq') || variation.contains('spaq');
}

/// Applies LGA → Bednet, Health → SPAQ; unknown / empty usage → no constraint.
bool productMatchesInventoryUsageSide(ProductVariantModel p, String? usage) {
  final u = (usage ?? '').trim();
  if (u.isEmpty || u == 'None') return true;
  if (isUsageLgaSide(u)) return matchesBednetProduct(p);
  if (isUsageHealthFacility(u)) return matchesSpaqProduct(p);
  return true;
}

/// Intersection: product must satisfy both [sourceUsage] and [destinationUsage]
/// when each is provided.
List<ProductVariantModel> filterProductVariantsBySourceAndDestinationUsage({
  required List<ProductVariantModel> variants,
  required String? sourceFacilityUsage,
  required String? destinationFacilityUsage,
}) {
  return variants
      .where(
        (p) =>
            productMatchesInventoryUsageSide(p, sourceFacilityUsage) &&
            productMatchesInventoryUsageSide(p, destinationFacilityUsage),
      )
      .toList();
}
