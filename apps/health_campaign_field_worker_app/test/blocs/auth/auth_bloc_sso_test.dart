import 'package:bloc_test/bloc_test.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/blocs/auth/auth.dart';
import 'package:health_campaign_field_worker_app/data/local_store/secure_store/secure_store.dart';
import 'package:health_campaign_field_worker_app/data/repositories/remote/auth.dart';
import 'package:health_campaign_field_worker_app/data/repositories/remote/mdms.dart';
import 'package:health_campaign_field_worker_app/data/services/azure_sso_service.dart';
import 'package:health_campaign_field_worker_app/models/auth/auth_model.dart';
import 'package:health_campaign_field_worker_app/models/role_actions/role_actions_model.dart';
import 'package:health_campaign_field_worker_app/utils/environment_config.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockMdmsRepository extends Mock implements MdmsRepository {}

class MockIndividualRepository extends Mock
    implements RemoteRepository<IndividualModel, IndividualSearchModel> {}

class MockSsoAuthenticator extends Mock implements SsoAuthenticator {}

class MockLocalSecureStore extends Mock implements LocalSecureStore {}

class FakeIndividualSearchModel extends Fake implements IndividualSearchModel {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tenantId = 'ng';
  const idToken = 'header.payload.signature';
  const user = UserRequestModel(uuid: 'user-uuid', userName: 'sso.user');
  const authModel = AuthModel(
    accessToken: 'digit-access',
    tokenType: 'bearer',
    refreshToken: 'digit-refresh',
    expiresIn: 3600,
    userRequestModel: user,
  );
  const actions = RoleActionsWrapperModel();

  late MockAuthRepository authRepository;
  late MockMdmsRepository mdmsRepository;
  late MockIndividualRepository individualRepository;
  late MockSsoAuthenticator sso;
  late MockLocalSecureStore store;

  setUpAll(() async {
    await envConfig.initialize();
    registerFallbackValue(
      const SsoExchangeRequestModel(idToken: '', tenantId: ''),
    );
    registerFallbackValue(authModel);
    registerFallbackValue(actions);
    registerFallbackValue(FakeIndividualSearchModel());
  });

  setUp(() {
    authRepository = MockAuthRepository();
    mdmsRepository = MockMdmsRepository();
    individualRepository = MockIndividualRepository();
    sso = MockSsoAuthenticator();
    store = MockLocalSecureStore();

    when(() => store.setAuthCredentials(any())).thenAnswer((_) async {});
    when(() => store.setBoundaryRefetch(any())).thenAnswer((_) async {});
    when(() => store.setRoleActions(any())).thenAnswer((_) async {});
    when(() => store.setSsoIdToken(any())).thenAnswer((_) async {});
    when(() => store.deleteAll()).thenAnswer((_) async {});
    when(() => store.userIndividualId).thenAnswer((_) async => null);
    when(() => sso.signOut(idTokenHint: any(named: 'idTokenHint')))
        .thenAnswer((_) async {});
    when(() => mdmsRepository.searchRoleActions(any(), any()))
        .thenAnswer((_) async => actions);
  });

  AuthBloc buildBloc({bool withSso = true}) => AuthBloc(
        authRepository: authRepository,
        mdmsRepository: mdmsRepository,
        individualRemoteRepository: individualRepository,
        ssoAuthenticator: withSso ? sso : null,
        localSecureStore: store,
      );

  group('AuthBloc SSO login', () {
    blocTest<AuthBloc, AuthState>(
      'exchanges the Azure ID token for a DIGIT session and authenticates',
      setUp: () {
        when(() => sso.signIn()).thenAnswer(
          (_) async => const SsoIdentity(
            idToken: idToken,
            accessToken: 'azure-access',
          ),
        );
        when(() => authRepository.exchangeSsoToken(
              request: any(named: 'request'),
              exchangePath: any(named: 'exchangePath'),
            )).thenAnswer((_) async => authModel);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.ssoLogin(tenantId: tenantId)),
      expect: () => const [
        AuthState.loading(),
        AuthState.authenticated(
          accessToken: 'digit-access',
          refreshToken: 'digit-refresh',
          userModel: user,
          actionsWrapper: actions,
        ),
      ],
      verify: (_) {
        final captured = verify(() => authRepository.exchangeSsoToken(
              request: captureAny(named: 'request'),
              exchangePath: captureAny(named: 'exchangePath'),
            )).captured;
        final request = captured[0] as SsoExchangeRequestModel;
        expect(request.idToken, idToken);
        expect(request.accessToken, 'azure-access');
        expect(request.tenantId, tenantId);
        expect(request.userType, 'EMPLOYEE');
        expect(request.provider, 'MICROSOFT');
        expect(captured[1], envConfig.variables.ssoTokenExchangePath);

        verify(() => store.setAuthCredentials(authModel)).called(1);
        verify(() => store.setRoleActions(actions)).called(1);
        verify(() => store.setSsoIdToken(idToken)).called(1);
        verifyNever(() => individualRepository.search(any()));
      },
    );

    blocTest<AuthBloc, AuthState>(
      'returns to unauthenticated without an error when the user cancels',
      setUp: () {
        when(() => sso.signIn()).thenThrow(const SsoCancelledException());
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.ssoLogin(tenantId: tenantId)),
      expect: () => const [
        AuthState.loading(),
        AuthState.unauthenticated(),
      ],
      verify: (_) {
        verifyNever(() => authRepository.exchangeSsoToken(
              request: any(named: 'request'),
              exchangePath: any(named: 'exchangePath'),
            ));
        verifyNever(() => store.setAuthCredentials(any()));
      },
    );

    blocTest<AuthBloc, AuthState>(
      'surfaces the configuration message when Azure settings are missing',
      setUp: () {
        when(() => sso.signIn())
            .thenThrow(const SsoConfigurationException('missing client id'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.ssoLogin(tenantId: tenantId)),
      expect: () => const [
        AuthState.loading(),
        AuthState.error('missing client id'),
        AuthState.unauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'reports a generic error when the DIGIT exchange fails',
      setUp: () {
        when(() => sso.signIn())
            .thenAnswer((_) async => const SsoIdentity(idToken: idToken));
        when(() => authRepository.exchangeSsoToken(
              request: any(named: 'request'),
              exchangePath: any(named: 'exchangePath'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: 'user/oauth/sso/_exchange'),
            response: Response(
              requestOptions: RequestOptions(path: 'user/oauth/sso/_exchange'),
              statusCode: 401,
              data: {'error': 'invalid_token'},
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.ssoLogin(tenantId: tenantId)),
      expect: () => const [
        AuthState.loading(),
        AuthState.error(),
        AuthState.unauthenticated(),
      ],
      verify: (_) {
        verifyNever(() => store.setAuthCredentials(any()));
        verifyNever(() => store.setSsoIdToken(any()));
      },
    );

    blocTest<AuthBloc, AuthState>(
      'reports a generic error when the provider fails after the browser step',
      setUp: () {
        when(() => sso.signIn())
            .thenThrow(const SsoException('no id token returned'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.ssoLogin(tenantId: tenantId)),
      expect: () => const [
        AuthState.loading(),
        AuthState.error(),
        AuthState.unauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'fails fast when the build has no SSO authenticator wired in',
      build: () => buildBloc(withSso: false),
      act: (bloc) => bloc.add(const AuthEvent.ssoLogin(tenantId: tenantId)),
      expect: () => const [
        AuthState.error('SSO is not available in this build'),
        AuthState.unauthenticated(),
      ],
    );
  });

  group('AuthBloc logout after SSO', () {
    blocTest<AuthBloc, AuthState>(
      'ends the Entra session with the stored ID token before clearing local state',
      setUp: () {
        when(() => store.ssoIdToken).thenAnswer((_) async => idToken);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.logout()),
      expect: () => const [AuthState.unauthenticated()],
      verify: (_) {
        verifyInOrder([
          () => sso.signOut(idTokenHint: idToken),
          () => store.deleteAll(),
        ]);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'skips the Entra end-session when the session was not an SSO one',
      setUp: () {
        when(() => store.ssoIdToken).thenAnswer((_) async => null);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.logout()),
      expect: () => const [AuthState.unauthenticated()],
      verify: (_) {
        verifyNever(() => sso.signOut(idTokenHint: any(named: 'idTokenHint')));
        verify(() => store.deleteAll()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'still logs out locally when the Entra end-session throws',
      setUp: () {
        when(() => store.ssoIdToken).thenAnswer((_) async => idToken);
        when(() => sso.signOut(idTokenHint: any(named: 'idTokenHint')))
            .thenThrow(const SsoException('network down'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.logout()),
      expect: () => const [AuthState.unauthenticated()],
      verify: (_) {
        verify(() => store.deleteAll()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'never touches Entra in password mode (no authenticator wired)',
      build: () => buildBloc(withSso: false),
      act: (bloc) => bloc.add(const AuthEvent.logout()),
      expect: () => const [AuthState.unauthenticated()],
      verify: (_) {
        verifyNever(() => store.ssoIdToken);
        verify(() => store.deleteAll()).called(1);
      },
    );
  });
}
