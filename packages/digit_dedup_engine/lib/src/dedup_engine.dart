import '../models/candidate_pair.dart';
import '../models/dedup_match.dart';
import '../models/dedup_result.dart';
import 'blocking_strategy.dart';
import 'matching_service.dart';

/// Main entry point for the deduplication engine.
///
/// Orchestrates the full dedup pipeline:
/// 1. Blocking - reduces search space using phonetic keys
/// 2. Matching - scores candidate pairs using multi-attribute similarity
/// 3. Decision - applies threshold to classify matches
class DedupEngine {
  final double matchThreshold;
  final MatchingService matchingService;
  final BlockingStrategy blockingStrategy;

  /// Whether phonetic blocking is used to shrink the comparison set.
  ///
  /// Blocking trades a small chance of a miss -- a duplicate whose given and
  /// family names both encode to a different Soundex code -- for a large drop
  /// in comparisons. Turn it off to compare against every record.
  final bool useBlocking;

  DedupEngine({
    this.matchThreshold = 0.85,
    MatchingService? matchingService,
    BlockingStrategy? blockingStrategy,
    this.useBlocking = true,
  })  : matchingService = matchingService ?? MatchingService(),
        blockingStrategy = blockingStrategy ?? BlockingStrategy();

  /// Run deduplication on a list of beneficiary records.
  ///
  /// Returns a list of [DedupResult] containing detected duplicate pairs
  /// with confidence scores.
  List<DedupResult> findDuplicates(List<Map<String, dynamic>> records) {
    if (records.length < 2) return const [];

    final results = <DedupResult>[];

    for (final pair in _candidatePairs(records)) {
      final scored = scorePair(records[pair.$1], records[pair.$2]);
      if (scored.overallScore < matchThreshold) continue;

      results.add(DedupResult(
        recordIndex1: pair.$1,
        recordIndex2: pair.$2,
        score: scored.overallScore,
        attributeScores: scored.scores,
        isDuplicate: true,
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Score one incoming [record] against a corpus of existing [records].
  ///
  /// This is the search-time counterpart to [findDuplicates]: rather than
  /// comparing a batch against itself, it answers "does this new registration
  /// already exist?". Returns the matches at or above [matchThreshold],
  /// highest score first, capped at [maxResults] when given.
  List<DedupMatch> findMatchesFor(
    Map<String, dynamic> record,
    List<Map<String, dynamic>> records, {
    int? maxResults,
  }) {
    if (records.isEmpty) return const [];

    final matches = <DedupMatch>[];

    for (final index in _candidateIndicesFor(record, records)) {
      final scored = scorePair(record, records[index]);
      if (scored.overallScore < matchThreshold) continue;

      matches.add(DedupMatch(
        recordIndex: index,
        record: records[index],
        score: scored.overallScore,
        attributeScores: scored.scores,
      ));
    }

    matches.sort((a, b) => b.score.compareTo(a.score));

    if (maxResults != null && matches.length > maxResults) {
      return matches.sublist(0, maxResults);
    }
    return matches;
  }

  /// Score a single pair of records for similarity.
  ///
  /// Returns a [CandidatePair] with individual attribute scores
  /// and a weighted overall score.
  CandidatePair scorePair(
    Map<String, dynamic> record1,
    Map<String, dynamic> record2, {
    int index1 = 0,
    int index2 = 1,
  }) {
    final scores = matchingService.computeAttributeScores(record1, record2);

    return CandidatePair(
      index1: index1,
      index2: index2,
      scores: scores,
      overallScore: matchingService.computeScore(record1, record2),
    );
  }

  /// Index pairs worth scoring, deduplicated across blocks.
  Iterable<(int, int)> _candidatePairs(List<Map<String, dynamic>> records) {
    if (!useBlocking) {
      return [
        for (var i = 0; i < records.length; i++)
          for (var j = i + 1; j < records.length; j++) (i, j),
      ];
    }

    // A record sits in one block per name attribute, so the same pair can
    // surface from several blocks; the set collapses those repeats.
    final pairs = <(int, int)>{};
    for (final block in blockingStrategy.buildBlocks(records).values) {
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

  /// Corpus indices worth scoring against [record].
  Iterable<int> _candidateIndicesFor(
    Map<String, dynamic> record,
    List<Map<String, dynamic>> records,
  ) {
    if (!useBlocking) {
      return Iterable<int>.generate(records.length);
    }

    final probeKeys = blockingStrategy.blockKeysFor(record);
    if (probeKeys.isEmpty) return const [];

    final blocks = blockingStrategy.buildBlocks(records);
    final candidates = <int>{};
    for (final key in probeKeys) {
      final block = blocks[key];
      if (block != null) candidates.addAll(block);
    }
    return candidates;
  }
}
