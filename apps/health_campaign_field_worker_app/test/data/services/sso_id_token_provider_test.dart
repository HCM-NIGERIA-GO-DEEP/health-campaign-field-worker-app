import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/local_store/secure_store/secure_store.dart';
import 'package:health_campaign_field_worker_app/data/services/azure_sso_service.dart';
import 'package:health_campaign_field_worker_app/data/services/sso_id_token_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalSecureStore extends Mock implements LocalSecureStore {}

class MockSsoAuthenticator extends Mock implements SsoAuthenticator {}

/// Unsigned JWT whose only meaningful claim is `exp`.
String jwt(DateTime expiry, {String sub = 'user'}) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.'
      '${part({'sub': sub, 'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.sig';
}

void main() {
  final now = DateTime.utc(2026, 9, 28, 12);
  late DateTime clock;
  late MockLocalSecureStore store;
  late MockSsoAuthenticator sso;
  late String? storedId;
  late String? storedRefresh;

  final fresh = jwt(now.add(const Duration(minutes: 30)));
  final nearlyExpired = jwt(now.add(const Duration(minutes: 2)));
  final expired = jwt(now.subtract(const Duration(hours: 3)));
  final renewed = jwt(now.add(const Duration(hours: 1)), sub: 'renewed');

  SsoIdTokenProvider provider() => SsoIdTokenProvider(
        store: store,
        authenticator: sso,
        now: () => clock,
      );

  setUp(() {
    clock = now;
    store = MockLocalSecureStore();
    sso = MockSsoAuthenticator();
    storedId = null;
    storedRefresh = null;

    when(() => store.ssoIdToken).thenAnswer((_) async => storedId);
    when(() => store.ssoRefreshToken).thenAnswer((_) async => storedRefresh);
    when(() => store.setSsoTokens(
          idToken: any(named: 'idToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((invocation) async {
      storedId = invocation.namedArguments[#idToken] as String;
      final rt = invocation.namedArguments[#refreshToken] as String?;
      if (rt != null) storedRefresh = rt;
    });
  });

  test('jwtExpiry reads exp and rejects non-JWTs', () {
    expect(
      SsoIdTokenProvider.jwtExpiry(fresh),
      now.add(const Duration(minutes: 30)),
    );
    expect(SsoIdTokenProvider.jwtExpiry('not-a-jwt'), isNull);
    expect(SsoIdTokenProvider.jwtExpiry('a.!!!.c'), isNull);
  });

  test('returns null without an SSO session', () async {
    expect(await provider().currentIdToken(), isNull);
    verifyNever(() => sso.refresh(refreshToken: any(named: 'refreshToken')));
  });

  test('returns a token with enough lifetime left without refreshing',
      () async {
    storedId = fresh;
    storedRefresh = 'rt-1';

    expect(await provider().currentIdToken(), fresh);
    verifyNever(() => sso.refresh(refreshToken: any(named: 'refreshToken')));
  });

  test('refreshes a token inside the skew window and stores the rotation',
      () async {
    storedId = nearlyExpired;
    storedRefresh = 'rt-1';
    when(() => sso.refresh(refreshToken: 'rt-1')).thenAnswer(
      (_) async => SsoIdentity(idToken: renewed, refreshToken: 'rt-2'),
    );

    expect(await provider().currentIdToken(), renewed);
    expect(storedId, renewed);
    expect(storedRefresh, 'rt-2');
  });

  test('keeps the old refresh token when Entra does not rotate it', () async {
    storedId = expired;
    storedRefresh = 'rt-1';
    when(() => sso.refresh(refreshToken: 'rt-1'))
        .thenAnswer((_) async => SsoIdentity(idToken: renewed));

    expect(await provider().currentIdToken(), renewed);
    expect(storedRefresh, 'rt-1');
  });

  test('treats an unreadable stored token as expired', () async {
    storedId = 'garbage';
    storedRefresh = 'rt-1';
    when(() => sso.refresh(refreshToken: 'rt-1'))
        .thenAnswer((_) async => SsoIdentity(idToken: renewed));

    expect(await provider().currentIdToken(), renewed);
  });

  test('concurrent callers share a single refresh', () async {
    storedId = expired;
    storedRefresh = 'rt-1';
    final gate = Completer<SsoIdentity>();
    when(() => sso.refresh(refreshToken: 'rt-1'))
        .thenAnswer((_) => gate.future);

    final p = provider();
    final calls = List.generate(5, (_) => p.currentIdToken());
    await Future<void>.delayed(Duration.zero);
    gate.complete(SsoIdentity(idToken: renewed, refreshToken: 'rt-2'));

    expect(await Future.wait(calls), everyElement(renewed));
    verify(() => sso.refresh(refreshToken: 'rt-1')).called(1);
  });

  test('sends the stale token when refresh fails, then backs off', () async {
    storedId = expired;
    storedRefresh = 'rt-1';
    when(() => sso.refresh(refreshToken: 'rt-1'))
        .thenThrow(const SsoException('offline'));

    final p = provider();
    expect(await p.currentIdToken(), expired);
    expect(await p.currentIdToken(), expired);
    verify(() => sso.refresh(refreshToken: 'rt-1')).called(1);

    clock = now.add(const Duration(minutes: 2));
    when(() => sso.refresh(refreshToken: 'rt-1'))
        .thenAnswer((_) async => SsoIdentity(idToken: renewed));
    expect(await p.currentIdToken(), renewed);
  });

  test('sends the stale token when there is no refresh token', () async {
    storedId = expired;

    expect(await provider().currentIdToken(), expired);
    verifyNever(() => sso.refresh(refreshToken: any(named: 'refreshToken')));
  });

  test('does not write tokens back if the session ended during refresh',
      () async {
    storedId = expired;
    storedRefresh = 'rt-1';
    when(() => sso.refresh(refreshToken: 'rt-1')).thenAnswer((_) async {
      // Logout clears the store while Microsoft is answering.
      storedId = null;
      storedRefresh = null;
      return SsoIdentity(idToken: renewed, refreshToken: 'rt-2');
    });

    expect(await provider().currentIdToken(), expired);
    verifyNever(() => store.setSsoTokens(
          idToken: any(named: 'idToken'),
          refreshToken: any(named: 'refreshToken'),
        ));
    expect(storedRefresh, isNull);
  });
}
