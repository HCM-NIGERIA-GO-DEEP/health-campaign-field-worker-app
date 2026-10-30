import 'package:dio/dio.dart';
import '../../../models/boundary_beneficiary_id.dart';

/// Keep the provisional route and response parsing isolated until confirmed.
class BoundaryBeneficiaryIdRepository {
  // Temporary test mapping until the backend route is available.
  static const dummyBoundaryIds = <String, int>{
    'ADMIN_KAMBIA_SI_01_01_09_17_03_YEBAYA_MCHP': 89,
  };
  final Dio client;
  final String tenantId;
  const BoundaryBeneficiaryIdRepository(this.client, {required this.tenantId});

  Future<BoundaryBeneficiaryIdMap> fetch() async {
    try {
      final response = await client.get<dynamic>(
        'boundary/unique_beneficiary_ids',
        queryParameters: {'tenantId': tenantId},
        // The shared AuthTokenInterceptor adds the same authenticated
        // RequestInfo envelope used by the existing application APIs.
        data: <String, dynamic>{},
      );
      if (response.data is! Map) {
        throw const FormatException('Expected a boundary mapping object');
      }
      final parsed = BoundaryBeneficiaryIdMap.fromJson(
          Map<String, dynamic>.from(response.data as Map));
      for (final entry in parsed.boundaryToNumericId.entries) {}
      return parsed;
    } catch (error) {
      return const BoundaryBeneficiaryIdMap(dummyBoundaryIds, isDummy: true);
    }
  }
}
