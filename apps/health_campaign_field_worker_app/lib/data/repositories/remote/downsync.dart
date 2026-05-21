// Generated using mason. Do not modify by hand

import 'package:digit_data_model/data_model.dart';
import 'package:dio/dio.dart';
import '../../../models/downsync/downsync.dart';

class DownsyncRemoteRepository
    extends RemoteRepository<DownsyncModel, DownsyncSearchModel> {
  DownsyncRemoteRepository(
    super.dio, {
    required super.actionMap,
    super.entityName = 'Downsync',
  });

  @override
  DataModelType get type => DataModelType.downsync;

  @override
  Future<Map<String, dynamic>> downSync(
    DownsyncSearchModel query, {
    int? offSet,
    int? limit,
  }) async {
    final response = await executeFuture<Response>(
      future: () async {
        return dio.post(
          searchPath,
          queryParameters: {
            'offset': offSet ?? 0,
            'limit': limit ?? 100,
            'tenantId': DigitDataModelSingleton().tenantId,
            if (query.isDeleted ?? false) 'includeDeleted': query.isDeleted,
          },
          data: {
            'DownsyncCriteria': query.toMap(),
          },
        );
      },
    );

    final responseMap = response.data;
    if (responseMap is! Map<String, dynamic>) {
      throw InvalidApiResponseException(
        data: query.toMap(),
        path: searchPath,
        response: responseMap,
      );
    }

    if (responseMap.containsKey('DownloadLinks')) {
      return responseMap;
    }

    if (responseMap.containsKey(entityName)) {
      final entityResponse = responseMap[entityName];
      if (entityResponse is Map<String, dynamic>) {
        return entityResponse;
      }
    }

    throw InvalidApiResponseException(
      data: query.toMap(),
      path: searchPath,
      response: responseMap,
    );
  }
}
