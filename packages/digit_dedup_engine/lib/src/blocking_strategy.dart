import '../utils/string_utils.dart';
import 'algorithms/soundex.dart';

/// Blocking strategy to reduce the search space for deduplication.
///
/// Instead of comparing every record with every other record (O(n^2)),
/// blocking groups records into blocks using phonetic keys.
/// Only records within the same block are compared.
class BlockingStrategy {
  /// Record attributes whose Soundex codes are used as block keys. A record is
  /// filed under one block per attribute, so a typo in the given name can
  /// still be caught through the family name.
  static const List<String> defaultKeyAttributes = ['givenName', 'familyName'];

  final List<String> keyAttributes;

  BlockingStrategy({List<String>? keyAttributes})
      : keyAttributes = keyAttributes ?? defaultKeyAttributes;

  /// Build blocks from a list of records.
  ///
  /// Groups records by their phonetic key (Soundex of givenName + familyName).
  /// Records in the same block are potential duplicate candidates.
  ///
  /// A record appears under every key it produces, so the same index can show
  /// up in more than one block.
  Map<String, List<int>> buildBlocks(List<Map<String, dynamic>> records) {
    final blocks = <String, List<int>>{};

    for (var i = 0; i < records.length; i++) {
      for (final key in blockKeysFor(records[i])) {
        blocks.putIfAbsent(key, () => <int>[]).add(i);
      }
    }

    return blocks;
  }

  /// The set of block keys a single record belongs to.
  ///
  /// Each key is prefixed with its source attribute so that a given name and a
  /// family name encoding to the same Soundex code stay in separate blocks.
  Set<String> blockKeysFor(Map<String, dynamic> record) {
    final keys = <String>{};

    for (final attribute in keyAttributes) {
      final raw = record[attribute];
      if (raw == null) continue;

      // A name field may hold several words ("Peter John"); each contributes
      // its own key so word order between records does not matter. Each word
      // also contributes a key per spelling form, so "Al-Mustapha" and
      // "Almustapha" share a block instead of being filed apart and never
      // compared.
      final normalized = StringUtils.normalizeName(raw.toString());
      for (final form in StringUtils.comparisonForms(normalized)) {
        for (final token in form.split(' ')) {
          if (token.isEmpty) continue;
          final code = Soundex.encode(token);
          if (code.isEmpty) continue;
          keys.add('$attribute:$code');
        }
      }
    }

    return keys;
  }
}
