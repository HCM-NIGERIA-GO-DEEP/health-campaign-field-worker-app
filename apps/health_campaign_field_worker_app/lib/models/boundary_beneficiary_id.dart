/// BoundaryIdentifier maps boundary-code strings to numeric identifier strings.
/// Values are validated before being used as beneficiary ID prefixes.
class BoundaryBeneficiaryIdMap {
  final Map<String, int> boundaryToNumericId;
  const BoundaryBeneficiaryIdMap(this.boundaryToNumericId);

  factory BoundaryBeneficiaryIdMap.fromJson(Map<String, dynamic> json) {
    final values = <String, int>{};
    for (final entry in json.entries) {
      final value = int.tryParse(entry.value.toString());
      if (entry.key.isEmpty || value == null || value < 0) {
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
