/// A single corpus record judged similar to a probe record.
///
/// Returned by `DedupEngine.findMatchesFor`, which scores one incoming record
/// against a corpus of existing ones. Unlike [DedupResult], which describes a
/// pair discovered inside a single batch, a match always relates the probe to
/// exactly one existing record.
class DedupMatch {
  /// Index of the matched record in the corpus list passed to the engine.
  final int recordIndex;

  /// The matched corpus record, returned verbatim so callers can read their
  /// own passthrough keys (identifiers, client reference ids, ...) off it.
  final Map<String, dynamic> record;

  /// Overall weighted similarity score (0.0 to 1.0).
  final double score;

  /// Individual attribute similarity scores that produced [score].
  final Map<String, double> attributeScores;

  const DedupMatch({
    required this.recordIndex,
    required this.record,
    required this.score,
    required this.attributeScores,
  });

  /// [score] expressed as a whole percentage, for display.
  int get scorePercentage => (score * 100).round();

  @override
  String toString() => 'DedupMatch(recordIndex: $recordIndex, score: $score, '
      'attributeScores: $attributeScores)';
}
