import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/repositories/api_interceptors.dart';
import 'package:health_campaign_field_worker_app/data/repositories/remote/boundary_beneficiary_id.dart';
import 'package:health_campaign_field_worker_app/data/local_store/secure_store/secure_store.dart';
import 'package:health_campaign_field_worker_app/models/auth/auth_model.dart';
import 'package:health_campaign_field_worker_app/utils/environment_config.dart';

class SecureStore extends Fake implements LocalSecureStore {
  @override
  Future<String?> get accessToken async => 'test-token';
  @override
  Future<UserRequestModel?> get userRequestModel async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await envConfig.initialize();
  });
  test('string mapping uses tenant and the shared authenticated RequestInfo',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/'));
    late RequestOptions request;
    dio.interceptors.add(AuthTokenInterceptor(localSecureStore: SecureStore()));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      request = options;
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
        'ResponseInfo': {},
        'BoundaryIdentifier': {'DP': '42'}
      }));
    }));
    final result = await BoundaryBeneficiaryIdRepository(dio, tenantId: 'si')
        .fetch(boundaryCode: 'DP', hierarchyType: 'ADMIN');
    expect(request.method, 'POST');
    expect(request.path, 'boundary-service/boundary-identifier/_search');
    expect(request.queryParameters, {
      'tenantId': 'si',
      'codes': 'DP',
      'hierarchyType': 'ADMIN',
      'offset': 0,
      'limit': 50,
    });
    expect(request.data['RequestInfo']['authToken'], 'test-token');
    expect(result.boundaryToNumericId, {'DP': 42});
  });
  test('non-map responses return no prefix', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
          requestOptions: options, statusCode: 200, data: ['invalid']));
    }));
    final result = await BoundaryBeneficiaryIdRepository(dio, tenantId: 'si')
        .fetch(boundaryCode: 'DP', hierarchyType: 'ADMIN');
    expect(result.boundaryToNumericId, isEmpty);
  });
  test('404 returns no prefix', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 404)));
    }));
    final result = await BoundaryBeneficiaryIdRepository(dio, tenantId: 'si')
        .fetch(boundaryCode: 'DP', hierarchyType: 'ADMIN');
    expect(result.boundaryToNumericId, isEmpty);
  });
  for (final mapping in [
    {},
    {'OTHER': 7},
    {'DP': 'invalid'}
  ]) {
    test('unusable mapping $mapping keeps the existing fallback', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        handler
            .resolve(Response(requestOptions: options, statusCode: 200, data: {
          'ResponseInfo': {'status': 'successful'},
          'BoundaryIdentifier': mapping
        }));
      }));
      final result = await BoundaryBeneficiaryIdRepository(dio, tenantId: 'si')
          .fetch(boundaryCode: 'DP', hierarchyType: 'ADMIN');
      expect(result.boundaryToNumericId, isEmpty);
    });
  }
}
