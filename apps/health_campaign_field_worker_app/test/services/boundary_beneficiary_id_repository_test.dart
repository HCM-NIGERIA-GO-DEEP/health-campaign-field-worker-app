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
  test('prefix request uses tenant and the shared authenticated RequestInfo',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/'));
    late RequestOptions request;
    dio.interceptors.add(AuthTokenInterceptor(localSecureStore: SecureStore()));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      request = options;
      handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: {'DP': 42}));
    }));
    final result =
        await BoundaryBeneficiaryIdRepository(dio, tenantId: 'si').fetch();
    expect(request.method, 'GET');
    expect(request.path, 'boundary/unique_beneficiary_ids');
    expect(request.queryParameters['tenantId'], 'si');
    expect(request.data['RequestInfo']['authToken'], 'test-token');
    expect(result.boundaryToNumericId, {'DP': 42});
  });
  test('non-map responses use the temporary dummy map', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(
          requestOptions: options, statusCode: 200, data: ['invalid']));
    }));
    final result =
        await BoundaryBeneficiaryIdRepository(dio, tenantId: 'si').fetch();
    expect(result.isDummy, true);
    expect(result.boundaryToNumericId,
        BoundaryBeneficiaryIdRepository.dummyBoundaryIds);
  });
  test('404 uses the temporary dummy map', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 404)));
    }));
    final result =
        await BoundaryBeneficiaryIdRepository(dio, tenantId: 'si').fetch();
    expect(result.isDummy, true);
    expect(
        result
            .boundaryToNumericId['ADMIN_KAMBIA_SI_01_01_09_17_03_YEBAYA_MCHP'],
        89);
  });
}
