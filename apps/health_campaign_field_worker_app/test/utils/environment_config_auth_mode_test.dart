import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/environment_config.dart';

void main() {
  Variables fromEnv(String contents) {
    final dotEnv = DotEnv()..testLoad(fileInput: contents);
    return Variables(dotEnv: dotEnv);
  }

  group('AUTH_MODE', () {
    test('defaults to password when unset or using fallbacks', () {
      expect(fromEnv('').authMode, AuthMode.password);
      expect(
        Variables(useFallbackValues: true, dotEnv: DotEnv()).authMode,
        AuthMode.password,
      );
    });

    test('is case-insensitive and tolerates whitespace', () {
      expect(fromEnv('AUTH_MODE=SSO').authMode, AuthMode.sso);
      expect(fromEnv('AUTH_MODE=sso').authMode, AuthMode.sso);
      expect(fromEnv('AUTH_MODE= Sso ').authMode, AuthMode.sso);
      expect(fromEnv('AUTH_MODE=password').authMode, AuthMode.password);
    });

    test('falls back to password for unknown or blank values', () {
      expect(fromEnv('AUTH_MODE=oauth').authMode, AuthMode.password);
      expect(fromEnv('AUTH_MODE=').authMode, AuthMode.password);
    });
  });

  group('Azure settings', () {
    test('parses scopes separated by spaces or commas', () {
      expect(
        fromEnv('AZURE_SCOPES=openid, profile  email').azureScopes,
        ['openid', 'profile', 'email'],
      );
    });

    test('ships no tenant or client by default (public repo)', () {
      final v = fromEnv('');
      expect(v.azureTenantId, isEmpty);
      expect(v.azureClientId, isEmpty);
      expect(v.azureRedirectUri, 'com.digit.hcm://oauth/callback');
      expect(v.azureScopes, ['openid', 'profile']);
      expect(v.ssoTokenExchangePath, 'user/oauth/sso/_exchange');
      expect(v.azureEndSessionOnLogout, isTrue);
    });

    test('a blank .env value keeps the shipped default (CI writes empty keys)',
        () {
      final v = fromEnv('AZURE_REDIRECT_URI=\nAZURE_SCOPES=\nAUTH_MODE=');
      expect(v.azureRedirectUri, 'com.digit.hcm://oauth/callback');
      expect(v.azureScopes, ['openid', 'profile']);
      expect(v.authMode, AuthMode.password);
    });

    test('.env values override the defaults', () {
      final v = fromEnv(
        'AZURE_TENANT_ID=tenant-guid\n'
        'AZURE_CLIENT_ID=client-guid\n'
        'AZURE_SCOPES=openid profile api://client-guid/access_as_user\n'
        'AZURE_END_SESSION_ON_LOGOUT=false',
      );
      expect(v.azureTenantId, 'tenant-guid');
      expect(v.azureClientId, 'client-guid');
      expect(v.azureScopes, hasLength(3));
      expect(v.azureEndSessionOnLogout, isFalse);
    });
  });
}
