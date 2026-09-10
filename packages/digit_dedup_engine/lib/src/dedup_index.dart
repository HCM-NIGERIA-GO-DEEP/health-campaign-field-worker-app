import 'blocking_strategy.dart';

/// A phonetic index over a corpus, built once and reused across probes.
///
/// `DedupEngine.findMatchesFor` builds one of these per call, which measured
/// roughly 80% of a probe's cost at 200,000 candidates (see
/// `PERFORMANCE.md`). When several records are scored against the same corpus,
/// build the index once and pass it to `DedupEngine.findMatchesUsing`.
///
/// The index holds a reference to [records] rather than a copy, so mutating
/// that list after building invalidates the index.
class DedupIndex {
  /// The corpus this index was built over.
  final List<Map<String, dynamic>> records;

  /// The strategy that produced the block keys, reused when looking up
  /// candidates so a probe is keyed the same way the corpus was.
  final BlockingStrategy blockingStrategy;

  final Map<String, List<int>> _blocks;

  const DedupIndex._(this.records, this.blockingStrategy, this._blocks);

  /// Builds the block index over [records].
  factory DedupIndex.build(
    List<Map<String, dynamic>> records, {
    BlockingStrategy? blockingStrategy,
  }) {
    final strategy = blockingStrategy ?? BlockingStrategy();
    return DedupIndex._(records, strategy, strategy.buildBlocks(records));
  }

  /// Number of records indexed.
  int get length => records.length;

  /// Number of distinct block keys. A count close to [length] means blocking
  /// is discriminating well; a small count means most records share a block
  /// and little comparison work is being avoided.
  int get blockCount => _blocks.length;

  /// Size of the largest block, i.e. the worst-case candidate count for a
  /// single probe.
  int get largestBlock =>
      _blocks.values.fold(0, (a, b) => b.length > a ? b.length : a);

  /// Corpus indices sharing at least one block key with [record].
  Set<int> candidatesFor(Map<String, dynamic> record) {
    final keys = blockingStrategy.blockKeysFor(record);
    if (keys.isEmpty) return const {};

    final candidates = <int>{};
    for (final key in keys) {
      final block = _blocks[key];
      if (block != null) candidates.addAll(block);
    }
    return candidates;
  }

  /// Every index pair worth scoring, each pair reported once.
  ///
  /// A record sits in one block per name attribute, so the same pair can
  /// surface from several blocks; the set collapses those repeats.
  Set<(int, int)> candidatePairs() {
    final pairs = <(int, int)>{};

    for (final block in _blocks.values) {
      if (block.length < 2) continue;
      for (var i = 0; i < block.length; i++) {
        for (var j = i + 1; j < block.length; j++) {
          final a = block[i];
          final b = block[j];
          pairs.add(a < b ? (a, b) : (b, a));
        }
      }
    }

    return pairs;
  }
}
