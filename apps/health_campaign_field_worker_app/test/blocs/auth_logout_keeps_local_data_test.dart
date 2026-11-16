import 'dart:convert';

import 'package:digit_data_model/data_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/blocs/auth/auth.dart';
import 'package:health_campaign_field_worker_app/data/local_store/secure_store/secure_store.dart';
import 'package:health_campaign_field_worker_app/data/repositories/remote/auth.dart';
import 'package:health_campaign_field_worker_app/data/repositories/remote/mdms.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockMdmsRepository extends Mock implements MdmsRepository {}

class _MockIndividualRemote extends Mock
    implements RemoteRepository<IndividualModel, IndividualSearchModel> {}

// No stubs: any read or write on the local stores fails the test, and
// verifyZeroInteractions proves logout never reached them.
class _MockIsar extends Mock implements Isar {}

class _MockSql extends Mock implements LocalSqlDataStore {}

// Devices are shared between roles (registrar, then distributor on the same
// phone). Logout used to delete every local table and the opLog outbox, so the
// next user's proximity search found nothing. Logout must end the session only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthRepository authRepository;
  late _MockIsar isar;
  late _MockSql sql;

  AuthBloc buildBloc() => AuthBloc(
        authRepository: authRepository,
        mdmsRepository: _MockMdmsRepository(),
        individualRemoteRepository: _MockIndividualRemote(),
        isar: isar,
        sql: sql,
      );

  setUp(() {
    authRepository = _MockAuthRepository();
    isar = _MockIsar();
    sql = _MockSql();
    when(() => authRepository.logOutUser(
          logoutPath: any(named: 'logoutPath'),
          body: any(named: 'body'),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async {});
    FlutterSecureStorage.setMockInitialValues({
      LocalSecureStore.accessTokenKey: 'token',
      LocalSecureStore.userObjectKey: jsonEncode({
        'uuid': 'registrar-uuid',
        'tenantId': 'si',
      }),
    });
  });

  test('a successful logout ends the session without touching local data',
      () async {
    final bloc = buildBloc();
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AuthLogoutEvent());
    await pumpEventQueue();

    expect(states, [const AuthUnauthenticatedState()]);
    verify(() => authRepository.logOutUser(
          logoutPath: any(named: 'logoutPath'),
          body: any(named: 'body'),
          queryParameters: any(named: 'queryParameters'),
        )).called(1);
    verifyZeroInteractions(sql);
    verifyZeroInteractions(isar);
    // The session itself is still cleared.
    expect(await LocalSecureStore.instance.accessToken, isNull);

    await sub.cancel();
    await bloc.close();
  });
}
