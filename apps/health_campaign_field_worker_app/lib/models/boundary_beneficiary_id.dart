/// BoundaryIdentifier maps boundary-code strings to numeric identifier strings.
/// Values are validated before being used as beneficiary ID prefixes.
class BoundaryBeneficiaryIdMap {
  // Held as String, not int. The service sends zero-padded fixed-width codes
  // ("0255"), and int.tryParse drops the padding - the ID was composed and
  // persisted as "255_xx" instead of "0255_xx", so the prefix width varied
  // with the code's magnitude and no longer matched what the backend issued.
  // Nothing arithmetic is ever done with this value; it is pure prefix text.
  final Map<String, String> boundaryToNumericId;
  const BoundaryBeneficiaryIdMap(this.boundaryToNumericId);

  factory BoundaryBeneficiaryIdMap.fromJson(Map<String, dynamic> json) {
    final values = <String, String>{};
    for (final entry in json.entries) {
      final value = entry.value?.toString() ?? '';
      // Still digits-only, so a malformed mapping is rejected as loudly as
      // before - we drop the int round-trip, not the validation.
      if (entry.key.isEmpty ||
          value.isEmpty ||
          !RegExp(r'^\d+$').hasMatch(value)) {
        throw const FormatException('Invalid numeric boundary mapping');
      }
      values[entry.key] = value;
    }
    return BoundaryBeneficiaryIdMap(values);
  }
}

class DistributionPointReference {
  final String code;
  final String name;
  const DistributionPointReference(this.code, this.name);
}

class BeneficiaryIdAllocation {
  final String rawId;
  final String identifier;
  const BeneficiaryIdAllocation(this.rawId, this.identifier);
}
