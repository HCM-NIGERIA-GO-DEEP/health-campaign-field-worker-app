import 'dart:async';

import 'package:collection/collection.dart';
import 'package:digit_ui_components/utils/app_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

EnvironmentConfiguration envConfig = EnvironmentConfiguration.instance;

class EnvironmentConfiguration {
  static final EnvironmentConfiguration _instance =
      EnvironmentConfiguration._internal();

  static EnvironmentConfiguration get instance => _instance;

  EnvironmentConfiguration._internal();

  bool _initialized = false;

  late DotEnv _dotEnv;
  late Variables _variables;

  FutureOr<void> initialize() async {
    _dotEnv = DotEnv();
    try {
      await _dotEnv.load();
      _variables = Variables(dotEnv: _dotEnv);
    } catch (error) {
      AppLogger.instance.error(
        title: runtimeType.toString(),
        message: 'Error while accessing .env file. Using fallback values',
      );

      _variables = Variables(useFallbackValues: true, dotEnv: _dotEnv);
    } finally {
      _initialized = true;
    }
  }

  Variables get variables {
    if (!_initialized) {
      throw Exception('EnvironmentConfiguration has not been initialized');
    }

    return _variables;
  }
}

class Variables {
  final DotEnv _dotEnv;
  final bool useFallbackValues;

  static const _connectTimeoutValue = 6000;
  static const _receiveTimeoutValue = 6000;
  static const _sendTimeoutValue = 6000;
  static const _retryTimeIntervalValue = 5;
  static const _syncDownRetryCountValue = 3;
  static const _minRamThresholdGbValue = 2.0;

  static const _envName = EnvEntry(
    'ENV_NAME',
    'DEV',
  );

  static const _connectTimeout = EnvEntry(
    'CONNECT_TIMEOUT',
    '$_connectTimeoutValue',
  );

  static const _receiveTimeout = EnvEntry(
    'RECEIVE_TIMEOUT',
    '$_connectTimeoutValue',
  );

  static const _dumpErrorApi = EnvEntry(
    'DUMP_ERROR_PATH',
    'error-handler/handle-error',
  );

  static const _syncDownRetryCount = EnvEntry(
    'SYNC_DOWN_RETRY_COUNT',
    '$_syncDownRetryCountValue',
  );

  static const _retryTimeInterval = EnvEntry(
    'RETRY_TIME_INTERVAL',
    '$_retryTimeIntervalValue',
  );
  static const _sendTimeout = EnvEntry(
    'SEND_TIMEOUT',
    '$_connectTimeoutValue',
  );

  static const _baseUrl = EnvEntry(
    'BASE_URL',
    'https://health-dev.digit.org/',
  );

  static const _checkBandwidthApi = EnvEntry(
    'CHECK_BANDWIDTH_API',
    '/health-project/check/bandwidth',
  );

  static const _summaryReportApi = EnvEntry(
    'SUMMARY_REPORT_API_PATH',
    'product/summary/v1/_search',
  );

  static const _mdmsApi = EnvEntry(
    'MDMS_API_PATH', //override mdms path to 'egov-mdms-service/v1/_search' for unified-uat in .env
    'mdms-v2/v1/_search',
  );

  static const _tenantId = EnvEntry(
    'TENANT_ID',
    'default',
  );

  static const _actionMapUrl = EnvEntry(
    'ACTIONS_API_PATH',
    'access/v1/actions/mdms/_get',
  );

  static const _hierarchyType = EnvEntry(
    'HIERARCHY_TYPE',
    'ADMIN',
  );

  static const _minRamThresholdGb = EnvEntry(
    'MIN_RAM_THRESHOLD_GB',
    '$_minRamThresholdGbValue',
  );

  static const _smcRiCampaignId = EnvEntry(
    'SMC_RI_CAMPAIGN_ID',
    '',
  );

  static const _orsZincCampaignId = EnvEntry(
    'ORS_ZINC_CAMPAIGN_ID',
    '',
  );

  // Selects how the login page authenticates. PASSWORD keeps the DIGIT
  // username/password form; SSO shows only a Microsoft sign-in button that
  // runs an Azure Entra ID authorization-code flow and exchanges the resulting
  // ID token for a DIGIT session via [ssoTokenExchangePath].
  static const _authMode = EnvEntry(
    'AUTH_MODE',
    'PASSWORD',
  );

  // Entra ID directory (tenant) ID, or `common` / `organizations` for
  // multi-tenant registrations.
  // Deployment specific: supplied via .env / CI variables, never committed.
  static const _azureTenantId = EnvEntry(
    'AZURE_TENANT_ID',
    '',
  );

  // Application (client) ID of the Entra ID app registration.
  // Deployment specific: supplied via .env / CI variables, never committed.
  static const _azureClientId = EnvEntry(
    'AZURE_CLIENT_ID',
    '',
  );

  // Must match a redirect URI registered on the Entra app and the
  // `appAuthRedirectScheme` manifest placeholder / iOS URL scheme.
  static const _azureRedirectUri = EnvEntry(
    'AZURE_REDIRECT_URI',
    'com.digit.hcm://oauth/callback',
  );

  // Space-separated scopes requested from Entra ID. Deployments should add
  // their `api://<client id>/access_as_user` scope so Entra issues an access
  // token whose audience is the app registration, which is what the DIGIT
  // exchange endpoint validates.
  static const _azureScopes = EnvEntry(
    'AZURE_SCOPES',
    'openid profile',
  );

  // When true, logging out in SSO mode also opens the Entra ID end-session
  // endpoint so the browser session is cleared for the next user.
  static const _azureEndSessionOnLogout = EnvEntry(
    'AZURE_END_SESSION_ON_LOGOUT',
    'true',
  );

  // DIGIT endpoint (relative to BASE_URL) that accepts an Azure ID token and
  // returns the standard DIGIT OAuth token response.
  static const _ssoTokenExchangePath = EnvEntry(
    'SSO_TOKEN_EXCHANGE_PATH',
    'user/oauth/sso/_exchange',
  );

  const Variables({
    this.useFallbackValues = false,
    required DotEnv dotEnv,
  }) : _dotEnv = dotEnv;

  String get baseUrl => useFallbackValues
      ? _baseUrl.value
      : _dotEnv.get(_baseUrl.key, fallback: _baseUrl.value);

  String get checkBandwidthApiPath => useFallbackValues
      ? _checkBandwidthApi.value
      : _dotEnv.get(_checkBandwidthApi.key, fallback: _checkBandwidthApi.value);

  String get summaryReportApiPath => useFallbackValues
      ? _summaryReportApi.value
      : _dotEnv.get(_summaryReportApi.key, fallback: _summaryReportApi.value);

  String get mdmsApiPath => useFallbackValues
      ? _mdmsApi.value
      : _dotEnv.get(_mdmsApi.key, fallback: _mdmsApi.value);

  String get hierarchyType => useFallbackValues
      ? _hierarchyType.value
      : _dotEnv.get(_hierarchyType.key, fallback: _hierarchyType.value);

  String get actionMapApiPath => useFallbackValues
      ? _actionMapUrl.value
      : _dotEnv.get(_actionMapUrl.key, fallback: _actionMapUrl.value);

  String get tenantId => useFallbackValues
      ? _tenantId.value
      : _dotEnv.get(_tenantId.key, fallback: _tenantId.value);

  String get dumpErrorApiPath => useFallbackValues
      ? _dumpErrorApi.value
      : _dotEnv.get(_dumpErrorApi.key, fallback: _dumpErrorApi.value);

  int get connectTimeout => useFallbackValues
      ? int.tryParse(_connectTimeout.value) ?? _connectTimeoutValue
      : int.tryParse(_dotEnv.get(
            _connectTimeout.key,
            fallback: _connectTimeout.value,
          )) ??
          _connectTimeoutValue;

  int get receiveTimeout => useFallbackValues
      ? int.tryParse(_receiveTimeout.value) ?? _receiveTimeoutValue
      : int.tryParse(_dotEnv.get(
            _receiveTimeout.key,
            fallback: _receiveTimeout.value,
          )) ??
          _receiveTimeoutValue;

  int get sendTimeout => useFallbackValues
      ? int.tryParse(_sendTimeout.value) ?? _sendTimeoutValue
      : int.tryParse(_dotEnv.get(
            _sendTimeout.key,
            fallback: _sendTimeout.value,
          )) ??
          _sendTimeoutValue;

  int get syncDownRetryCount => useFallbackValues
      ? int.tryParse(_syncDownRetryCount.value) ?? _syncDownRetryCountValue
      : int.tryParse(_dotEnv.get(
            _syncDownRetryCount.key,
            fallback: _syncDownRetryCount.value,
          )) ??
          _syncDownRetryCountValue;

  int get retryTimeInterval => useFallbackValues
      ? int.tryParse(_retryTimeInterval.value) ?? _retryTimeIntervalValue
      : int.tryParse(_dotEnv.get(
            _retryTimeInterval.key,
            fallback: _retryTimeInterval.value,
          )) ??
          _retryTimeIntervalValue;

  double get minRamThresholdGb => useFallbackValues
      ? double.tryParse(_minRamThresholdGb.value) ?? _minRamThresholdGbValue
      : double.tryParse(_dotEnv.get(
            _minRamThresholdGb.key,
            fallback: _minRamThresholdGb.value,
          )) ??
          _minRamThresholdGbValue;

  String get smcRiCampaignId => useFallbackValues
      ? _smcRiCampaignId.value
      : _dotEnv.get(_smcRiCampaignId.key, fallback: _smcRiCampaignId.value);

  String get orsZincCampaignId => useFallbackValues
      ? _orsZincCampaignId.value
      : _dotEnv.get(
          _orsZincCampaignId.key,
          fallback: _orsZincCampaignId.value,
        );

  /// Reads [entry] from `.env`, treating a missing *or blank* value as
  /// "use the shipped default". The build workflow writes every key even when
  /// the repository variable is unset, which would otherwise yield ''.
  String _valueOrDefault(EnvEntry entry) {
    if (useFallbackValues) return entry.value;
    final raw = _dotEnv.get(entry.key, fallback: entry.value).trim();
    return raw.isEmpty ? entry.value : raw;
  }

  AuthMode get authMode {
    final raw = _valueOrDefault(_authMode);

    return AuthMode.values.firstWhereOrNull(
          (mode) => mode.name.toUpperCase() == raw.trim().toUpperCase(),
        ) ??
        AuthMode.password;
  }

  String get azureTenantId => _valueOrDefault(_azureTenantId);

  String get azureClientId => _valueOrDefault(_azureClientId);

  String get azureRedirectUri => _valueOrDefault(_azureRedirectUri);

  bool get azureEndSessionOnLogout =>
      _valueOrDefault(_azureEndSessionOnLogout).toLowerCase() != 'false';

  List<String> get azureScopes {
    final raw = _valueOrDefault(_azureScopes);

    return raw
        .split(RegExp(r'[\s,]+'))
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toList();
  }

  String get ssoTokenExchangePath => _valueOrDefault(_ssoTokenExchangePath);

  EnvType get envType {
    final envName = useFallbackValues
        ? _envName.value
        : _dotEnv.get(_envName.key, fallback: _envName.value);

    return EnvType.values.firstWhereOrNull((env) => env.name == envName) ??
        EnvType.dev;
  }
}

class EnvEntry {
  final String key;
  final String value;

  const EnvEntry(this.key, this.value);
}

/// How the login page authenticates the user. See `AUTH_MODE` in `.env`.
enum AuthMode {
  /// DIGIT username/password form (default).
  password,

  /// Azure Entra ID single sign-on via the system browser.
  sso,
}

enum EnvType {
  dev("DEV"),
  uat("UAT"),
  qa("QA"),
  prod("PROD"),
  demo("DEMO");

  final String env;

  const EnvType(this.env);

  String get name => env;
}
