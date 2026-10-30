import 'package:dio/dio.dart';
import '../../../models/boundary_beneficiary_id.dart';

/// Boundary identifiers are requested for the selected distribution point.
class BoundaryBeneficiaryIdRepository {
  final Dio client;
  final String tenantId;
  const BoundaryBeneficiaryIdRepository(this.client, {required this.tenantId});

  Future<BoundaryBeneficiaryIdMap> fetch({
    required String boundaryCode,
    required String hierarchyType,
  }) async {
    const path = 'boundary-service/boundary-identifier/_search';
    final query = {
      'tenantId': tenantId,
      'codes': boundaryCode,
      'offset': 0,
      'limit': 50,
      'hierarchyType': hierarchyType,
    };
    try {
      final response = await client.post<dynamic>(
        path,
        queryParameters: query,
        // Shared AuthTokenInterceptor supplies the authenticated RequestInfo.
        data: <String, dynamic>{},
      );
      final body = response.data;
      final mapping = body is Map ? body['BoundaryIdentifier'] : null;
      if (mapping is! Map || mapping.isEmpty) {
        throw const FormatException('Missing or empty BoundaryIdentifier map');
      }
      final parsed =
          BoundaryBeneficiaryIdMap.fromJson(Map<String, dynamic>.from(mapping));
      if (!parsed.boundaryToNumericId.containsKey(boundaryCode)) {
        throw const FormatException(
            'Selected boundary has no numeric identifier');
      }
      return parsed;
    } catch (_) {
      return const BoundaryBeneficiaryIdMap({});
    }
  }
}
