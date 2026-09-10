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
  /// Weights are relative, not absolute: [computeScore] renormalizes over
  /// whichever attributes both records actually carry, so the table does not
  /// need to sum to 1.0 and adding an attribute cannot change the score of a
  /// pair that does not carry it.
  static const Map<String, double> defaultWeights = {
    'givenName': 0.25,
    'familyName': 0.20,
    'dateOfBirth': 0.15,
    'gender': 0.05,
    'fatherName': 0.10,
    'gpsProximity': 0.15,
    'phoneticMatch': 0.10,

    // Weighted high because it discriminates where names cannot: in a dense
    // boundary many people genuinely share a name, and a differing phone
    // number is the cheapest signal that they are different people.
    'mobileNumber': 0.20,
  };

  /// Attributes scored with fuzzy string similarity.
  static const List<String> _nameAttributes = [
    'givenName',
    'familyName',
    'fatherName',
  ];

  static final RegExp _nonDigits = RegExp(r'[^0-9]');
  static final RegExp _hasAlphanumeric = RegExp(r'[A-Z0-9]');

  /// How many trailing digits of a phone number are compared. Nine covers a
  /// subscriber number without its country code.
  static const int _significantPhoneDigits = 9;

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
      final a = _comparisonForms(record1[attribute]);
      final b = _comparisonForms(record2[attribute]);
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

    final mobile =
        _mobileNumberScore(record1['mobileNumber'], record2['mobileNumber']);
    if (mobile != null) scores['mobileNumber'] = mobile;

    final proximity = _proximityScore(record1, record2);
    if (proximity != null) scores['gpsProximity'] = proximity;

    return scores;
  }

  /// Best blended similarity across the spelling forms of two names.
  ///
  /// Each name contributes more than one form (see
  /// [StringUtils.comparisonForms]); the best pairing wins so that a spelling
  /// variation can only ever help.
  double _nameSimilarity(List<String> a, List<String> b) {
    var best = 0.0;

    for (final formA in a) {
      for (final formB in b) {
        if (formA == formB) return 1.0;
        final jaroWinkler = JaroWinkler.similarity(formA, formB);
        final levenshtein = Levenshtein.similarity(formA, formB);
        final blended = (jaroWinkler * _jaroWinklerShare) +
            (levenshtein * (1 - _jaroWinklerShare));
        if (blended > best) best = blended;
      }
    }

    return best;
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
      final a = _comparisonForms(record1[attribute]);
      final b = _comparisonForms(record2[attribute]);
      if (a == null || b == null) continue;
      compared++;

      // Agreement through any pair of forms counts, matching how
      // [_nameSimilarity] takes the best pairing.
      final codesB = b.map(Soundex.encode).toSet();
      if (a.any((form) => codesB.contains(Soundex.encode(form)))) agreed++;
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

  /// Exact match on the significant digits of a phone number.
  ///
  /// Compares the last [_significantPhoneDigits] so a number stored with a
  /// country code matches the same number stored without one. Returns null
  /// when either side is absent -- the field is optional on the registration
  /// form, and a missing number is no evidence either way.
  double? _mobileNumberScore(dynamic value1, dynamic value2) {
    final a = _significantDigits(value1);
    final b = _significantDigits(value2);
    if (a == null || b == null) return null;
    return a == b ? 1.0 : 0.0;
  }

  /// The trailing digits of a phone number, or null when there are too few to
  /// compare meaningfully.
  static String? _significantDigits(dynamic value) {
    if (value == null) return null;

    final digits = value.toString().replaceAll(_nonDigits, '');
    if (digits.length < _significantPhoneDigits) return null;

    return digits.substring(digits.length - _significantPhoneDigits);
  }

  /// Exact match on a categorical value, e.g. gender.
  ///
  /// Requires at least one letter or digit on both sides, so a placeholder
  /// like `--` or `N/A` is treated as absent rather than as a value that
  /// mismatches. Every other attribute already rejects unusable input -- a
  /// name of punctuation normalizes to nothing, an unparseable date parses to
  /// null, a number with too few digits is skipped -- and this keeps
  /// categorical fields consistent with them, so junk cannot drag a score
  /// down.
  double? _exactScore(dynamic value1, dynamic value2) {
    final a = _categorical(value1);
    final b = _categorical(value2);
    if (a == null || b == null) return null;
    return a == b ? 1.0 : 0.0;
  }

  static String? _categorical(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim().toUpperCase();
    if (normalized.isEmpty) return null;
    if (!_hasAlphanumeric.hasMatch(normalized)) return null;
    return normalized;
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

  /// The forms a name value should be compared through, or null when there is
  /// nothing to compare.
  static List<String>? _comparisonForms(dynamic value) {
    if (value == null) return null;

    final normalized = StringUtils.normalizeName(value.toString());
    if (normalized.isEmpty) return null;

    final forms = StringUtils.comparisonForms(normalized)
        .where((form) => form.isNotEmpty)
        .toList();
    return forms.isEmpty ? null : forms;
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
