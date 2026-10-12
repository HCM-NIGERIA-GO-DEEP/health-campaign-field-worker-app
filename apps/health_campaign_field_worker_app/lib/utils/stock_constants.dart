/// Campaign-level stock settings.
///
/// A liquid campaign records stock in whole bottles but accounts for it in ml:
/// `stock.quantity` still travels to the server in bottles, while every
/// balance the app derives or renders is scaled to ml.
///
/// [isLiquid] is the only line to change when a state switches between a
/// liquid campaign and one counting whole units — everything else derives from
/// it, so the two can never drift out of step.
///
/// ## Unit convention
///
/// * `stock.quantity` (persisted, synced) is always in **base units**.
/// * `quantityWastage` / `quantityPartialUsed` additional fields are in
///   **display units**.
/// * Every balance the app computes, caches or shows is in **display units**.
/// * Delivery task quantities are recorded in **display units** and so are
///   added after conversion, never scaled.
class StockConstants {
  const StockConstants._();

  /// Whether stock is measured as a liquid rather than counted in whole units.
  static const bool isLiquid = true;

  /// Display units per base unit on a liquid campaign, i.e. ml per bottle.
  static const double mlPerBottle = 30.0;

  /// Conversion actually applied to balances. 1 on a whole-unit campaign,
  /// which makes every multiply and divide below a no-op.
  static const double multiplier = isLiquid ? mlPerBottle : 1.0;

  /// Whether partially used stock counts against stock in hand. A part-used
  /// bottle cannot be re-issued, so a liquid campaign deducts it.
  static const bool deductPartialUsed = isLiquid;

  /// Converts a base-unit amount (as persisted) to display units.
  static double toDisplayUnit(num baseValue) => baseValue * multiplier;

  /// Converts a display-unit amount back to base units (as persisted).
  static double toBaseUnit(num displayValue) => displayValue / multiplier;
}
