import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../models/boundary_beneficiary_id.dart';

/// Boundary identifiers are requested for the selected distribution point.
class BoundaryBeneficiaryIdRepository {
  final Dio client;
  final String tenantId;
  const BoundaryBeneficiaryIdRepository(this.client, {required this.tenantId});

  static void debug(String event, Map<String, dynamic> data) {
    assert(() {
      debugPrint('SLDBG:BENEFICIARY_PREFIX_$event ${jsonEncode(data)}');
      return true;
    }());
  }

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
      debug('RESPONSE', {
        'statusCode': response.statusCode,
        'boundaryCode': boundaryCode,
        'mappingType': mapping.runtimeType.toString(),
        'mappingCount': mapping is Map ? mapping.length : null,
        // Mapping only: never log RequestInfo, tokens, or user information.
        'mapping': mapping is Map ? mapping : null,
      });
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
    } catch (error) {
      debug('RESPONSE', {
        'boundaryCode': boundaryCode,
        'errorType': error.runtimeType.toString(),
        if (error is DioException) 'statusCode': error.response?.statusCode,
      });
      return const BoundaryBeneficiaryIdMap({});
    }
  }
}
