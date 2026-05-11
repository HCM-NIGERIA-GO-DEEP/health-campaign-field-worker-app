import 'package:digit_data_model/models/entities/product_variant.dart';

import 'constants.dart';

/// Shared product filtering rules based on a facility's MDMS `usage`.
///
/// This is intentionally independent from `inventory_product_filter.dart` so
/// existing inventory behaviour remains untouched while other widgets can reuse
/// the same usage-to-product mapping.
class ProductVariantUsageFilter {
  const ProductVariantUsageFilter._();

  static bool isLgaSideUsage(String? usage) {
    final u = (usage ?? '').trim();
    if (u.isEmpty) return false;
    if (u == Constants.districtFacility || u == Constants.lgaFacility) {
      return true;
    }
    final lower = u.toLowerCase();
    return (lower.contains('lga') || lower.contains('district')) &&
        !lower.contains('health');
  }

  static bool isHealthFacilityUsage(String? usage) {
    final u = (usage ?? '').trim();
    if (u.isEmpty) return false;
    if (u == Constants.healthFacility) return true;
    final lower = u.toLowerCase();
    return lower.contains('health facility') ||
        (lower.contains('health') && lower.contains('facility'));
  }

  static bool isDhFacilityUsage(String? usage) {
    final u = (usage ?? '').trim();
    if (u.isEmpty) return false;
    if (u == Constants.dhFacility) return true;
    final lower = u.toLowerCase();
    return lower.contains('warehouse') ||
        (lower.contains('dh') && lower.contains('facility'));
  }

  static bool isBednetProduct(ProductVariantModel product) {
    final sku = (product.sku ?? '').toLowerCase();
    final variation = (product.variation ?? '').toLowerCase();
    return sku.contains('bednet') || variation.contains('bednet');
  }

  static bool isSpaqProduct(ProductVariantModel product) {
    final sku = (product.sku ?? '').toLowerCase();
    final variation = (product.variation ?? '').toLowerCase();
    return sku.contains('spaq') || variation.contains('spaq');
  }

  /// Applies:
  /// - LGA/District/DH usage -> Bednet products
  /// - Health Facility usage -> SPAQ products
  /// - empty/None/unknown usage -> no product constraint
  static bool matchesUsage(ProductVariantModel product, String? usage) {
    final u = (usage ?? '').trim();
    if (u.isEmpty || u == 'None') return true;
    if (isLgaSideUsage(u) || isDhFacilityUsage(u)) {
      return isBednetProduct(product);
    }
    if (isHealthFacilityUsage(u)) {
      return isSpaqProduct(product);
    }
    return true;
  }

  /// Keeps products that match all provided usage constraints.
  static List<ProductVariantModel> filterByUsages({
    required List<ProductVariantModel> variants,
    required Iterable<String?> usages,
  }) {
    final normalizedUsages =
        usages.map((u) => u?.trim()).where((u) => u != null && u.isNotEmpty);

    return variants
        .where(
          (product) =>
              normalizedUsages.every((usage) => matchesUsage(product, usage)),
        )
        .toList();
  }

  /// Keeps products that match at least one meaningful usage constraint.
  ///
  /// Use this when a view represents stock from multiple facilities and there is
  /// no single selected facility, e.g. distributor stock received from different
  /// source facilities.
  static List<ProductVariantModel> filterByAnyUsage({
    required List<ProductVariantModel> variants,
    required Iterable<String?> usages,
  }) {
    final normalizedUsages = usages
        .map((u) => u?.trim())
        .where((u) => u != null && u.isNotEmpty && u != 'None')
        .toList();

    if (normalizedUsages.isEmpty) return variants;

    return variants
        .where(
          (product) =>
              normalizedUsages.any((usage) => matchesUsage(product, usage)),
        )
        .toList();
  }
}
