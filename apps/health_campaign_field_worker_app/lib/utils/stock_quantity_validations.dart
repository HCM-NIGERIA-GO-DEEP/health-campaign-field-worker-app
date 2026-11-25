import 'dart:math';

import 'package:digit_forms_engine/models/property_schema/property_schema.dart';

/// Stock quantities checked against the stock in hand, as the stock product
/// details page names them.
const stockCheckedQuantities = [
  'quantitySent',
  'quantityLost',
  'quantityDamaged',
  'quantityReturned',
];

/// The stock product details page's properties with one copy of each
/// [stockCheckedQuantities] field, and of its read-only `<field>Pieces` row,
/// per selected product (`quantitySent_item_0`, `quantitySentPieces_item_0`,
/// ...), each checked against that product's [stockInHand].
///
/// Stock in hand is in pieces, so the check sits on whichever field holds
/// pieces: the Pieces row while the quantity is typed in bales (it holds a
/// value only while it shows), the quantity itself otherwise - its check
/// stands aside while the Pieces row holds a value ("maxUnlessFilled"). The
/// quantity keeps its configured max either way.
///
/// The copies go where the field was, so the page keeps its order; copies
/// from an earlier selection are replaced. Validations start from
/// [configuredProperties] (the page as loaded) when it has the field.
/// [stockMessage] gives the error for a stock in hand.
Map<String, PropertySchema> stockCheckedQuantityFields({
  required Map<String, PropertySchema> properties,
  Map<String, PropertySchema>? configuredProperties,
  required List<int> stockInHand,
  required String Function(int stockInHand) stockMessage,
}) {
  String piecesOf(String field) => '${field}Pieces';
  final pieces = {for (final field in stockCheckedQuantities) piecesOf(field)};
  final checked = {...stockCheckedQuantities, ...pieces};
  String baseOf(String key) => key.replaceFirst(RegExp(r'_item_\d+$'), '');

  // Each field as configured, without the stock checks added here before.
  PropertySchema? configured(String field) {
    var schema = properties[field] ?? configuredProperties?[field];
    if (schema == null) {
      for (final entry in properties.entries) {
        if (baseOf(entry.key) == field) {
          schema = entry.value;
          break;
        }
      }
    }
    if (schema == null) return null;
    return schema.copyWith(
      validations: [
        for (final rule in schema.validations ?? const <ValidationRule>[])
          if (pieces.contains(field)
              ? rule.type != 'max' && rule.type != 'maxValue'
              : rule.type != 'maxUnlessFilled')
            rule,
      ],
    );
  }

  PropertySchema checkedCopy(PropertySchema schema, String field, int index) {
    final maxValue = stockInHand[index];
    final limit = min(maxValue, 10000000);
    final message = stockMessage(maxValue);
    return schema.copyWith(
      validations: [
        ...?schema.validations,
        // Always added, even with nothing in hand, so nothing can be
        // entered then.
        pieces.contains(field)
            ? ValidationRule(type: 'max', value: limit, message: message)
            : ValidationRule(
                type: 'maxUnlessFilled',
                value: {
                  'max': limit,
                  'unlessFilled': '${piecesOf(field)}_item_$index',
                },
                message: message,
              ),
      ],
      max: maxValue,
      maxValue: maxValue,
    );
  }

  final templates = {
    for (final field in checked) field: configured(field),
  };
  final result = <String, PropertySchema>{};
  final placed = <String>{};
  for (final entry in properties.entries) {
    final field = baseOf(entry.key);
    if (!checked.contains(field)) {
      result[entry.key] = entry.value;
      continue;
    }
    if (!placed.add(field)) continue;
    final template = templates[field];
    if (template == null) continue;
    for (var index = 0; index < stockInHand.length; index++) {
      result['${field}_item_$index'] = checkedCopy(template, field, index);
    }
  }
  return result;
}
