import '../utils/gps_utils.dart';
import '../utils/string_utils.dart';
import 'algorithms/jaro_winkler.dart';
import 'algorithms/levenshtein.dart';
import 'algorithms/soundex.dart';

/// Service that computes similarity scores between record attributes.
///
/// Uses a weighted combination of multiple similarity metrics:
/// - Phonetic similarity (Soundex, Double Metaphone)
/// - String similarity (Jaro-Winkler, Levenshtein)
/// - GPS proximity (Haversine distance)
/// - Exact match (gender, DOB)
///
/// Only attributes present in *both* records contribute. The weights of the
/// contributing attributes are renormalized to sum to 1.0, so a record pair
/// carrying names alone scores on the same 0..1 scale as a fully populated
/// pair rather than being capped at the names' share of the weights.
class MatchingService {
  /// Default attribute weights for scoring
  static const Map<String, double> defaultWeights = {
    'givenName': 0.25,
    'familyName': 0.20,
    'dateOfBirth': 0.15,
    'gender': 0.05,
    'fatherName': 0.10,
    'gpsProximity': 0.15,
    'phoneticMatch': 0.10,
  };

  /// Attributes scored with fuzzy string similarity.
  static const List<String> _nameAttributes = [
    'givenName',
    'familyName',
    'fatherName',
  ];

  /// Share of a name attribute's score taken from Jaro-Winkler, with the
  /// remainder from normalized Levenshtein. Jaro-Winkler leads because it
  /// rewards a shared prefix, which is where names are most reliable; the
  /// Levenshtein term keeps whole-string edit distance in play.
  static const double _jaroWinklerShare = 0.7;

  final Map<String, double> weights;

  MatchingService({Map<String, double>? weights})
      : weights = weights ?? defaultWeights;

  /// Compute weighted similarity score between two records.
  /// Returns a value between 0.0 (no match) and 1.0 (perfect match).
  double computeScore(
    Map<String, dynamic> record1,
    Map<String, dynamic> record2,
  ) {
    final scores = computeAttributeScores(record1, record2);
    if (scores.isEmpty) return 0.0;

    var weightedSum = 0.0;
    var totalWeight = 0.0;

    for (final entry in scores.entries) {
      final weight = weights[entry.key];
      if (weight == null || weight <= 0) continue;
      weightedSum += entry.value * weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) return 0.0;
    return weightedSum / totalWeight;
  }

  /// Score each attribute the two records have in common.
  ///
  /// Attributes missing or blank on either side are left out of the result
  /// entirely rather than scored as 0, so they neither reward nor penalize.
  Map<String, double> computeAttributeScores(
    Map<String, dynamic> record1,
    Map<String, dynamic> record2,
  ) {
    final scores = <String, double>{};

    for (final attribute in _nameAttributes) {
      final a = _normalized(record1[attribute]);
      final b = _normalized(record2[attribute]);
      if (a == null || b == null) continue;
      scores[attribute] = _nameSimilarity(a, b);
    }

    final phonetic = _phoneticScore(record1, record2);
    if (phonetic != null) scores['phoneticMatch'] = phonetic;

    final dob =
        _dateOfBirthScore(record1['dateOfBirth'], record2['dateOfBirth']);
    if (dob != null) scores['dateOfBirth'] = dob;

    final gender = _exactScore(record1['gender'], record2['gender']);
    if (gender != null) scores['gender'] = gender;

    final proximity = _proximityScore(record1, record2);
    if (proximity != null) scores['gpsProximity'] = proximity;

    return scores;
  }

  /// Blended fuzzy similarity for a pair of normalized name strings.
  double _nameSimilarity(String a, String b) {
    if (a == b) return 1.0;
    final jaroWinkler = JaroWinkler.similarity(a, b);
    final levenshtein = Levenshtein.similarity(a, b);
    return (jaroWinkler * _jaroWinklerShare) +
        (levenshtein * (1 - _jaroWinklerShare));
  }

  /// Fraction of the compared name attributes whose Soundex codes agree.
  ///
  /// Returns null when no name attribute is present on both records.
  double? _phoneticScore(
    Map<String, dynamic> record1,
    Map<String, dynamic> record2,
  ) {
    var compared = 0;
    var agreed = 0;

    for (final attribute in _nameAttributes) {
      final a = _normalized(record1[attribute]);
      final b = _normalized(record2[attribute]);
      if (a == null || b == null) continue;
      compared++;
      if (Soundex.encode(a) == Soundex.encode(b)) agreed++;
    }

    if (compared == 0) return null;
    return agreed / compared;
  }

  /// Exact match on the day, falling back to a partial credit for a shared
  /// birth year -- a common data-entry outcome when only the age is known.
  double? _dateOfBirthScore(dynamic value1, dynamic value2) {
    final a = _parseDate(value1);
    final b = _parseDate(value2);
    if (a == null || b == null) return null;

    if (a.year == b.year && a.month == b.month && a.day == b.day) return 1.0;
    if (a.year == b.year) return 0.5;
    return 0.0;
  }

  double? _exactScore(dynamic value1, dynamic value2) {
    final a = value1?.toString().trim().toUpperCase();
    final b = value2?.toString().trim().toUpperCase();
    if (a == null || b == null || a.isEmpty || b.isEmpty) return null;
    return a == b ? 1.0 : 0.0;
  }

  double? _proximityScore(
    Map<String, dynamic> record1,
    Map<String, dynamic> record2,
  ) {
    final lat1 = _parseDouble(record1['latitude']);
    final lon1 = _parseDouble(record1['longitude']);
    final lat2 = _parseDouble(record2['latitude']);
    final lon2 = _parseDouble(record2['longitude']);
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }
    return GpsUtils.proximityScore(lat1, lon1, lat2, lon2);
  }

  /// Normalizes a name value, returning null when there is nothing to compare.
  static String? _normalized(dynamic value) {
    if (value == null) return null;
    final normalized = StringUtils.removeAffixes(
      StringUtils.normalizeName(value.toString()),
    );
    return normalized.isEmpty ? null : normalized;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    final asString = value.toString().trim();
    if (asString.isEmpty) return null;

    final asMillis = int.tryParse(asString);
    if (asMillis != null) {
      return DateTime.fromMillisecondsSinceEpoch(asMillis);
    }

    // ISO first, then the dd/MM/yyyy the registration forms capture.
    final iso = DateTime.tryParse(asString);
    if (iso != null) return iso;

    final parts = asString.split(RegExp(r'[/\-.]'));
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
