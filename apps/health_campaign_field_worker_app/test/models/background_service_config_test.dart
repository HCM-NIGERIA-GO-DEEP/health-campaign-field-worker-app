import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/local_store/no_sql/schema/app_configuration.dart'
    as schema;
import 'package:health_campaign_field_worker_app/models/app_config/app_config_model.dart'
    as model;
import 'package:health_campaign_field_worker_app/utils/utils.dart';

const _baseJson = {
  'BATTERY_PERCENT_CUT_OFF': 20,
  'SERVICE_INTERVAL': 60,
  'API_CONCURRENCY': 2,
};

schema.AppConfiguration _configWith(bool? enabled) => schema.AppConfiguration()
  ..backgroundServiceConfig = (schema.BackgroundServiceConfig()
    ..enabled = enabled);

void main() {
  group('BACKGROUND_SERVICE_CONFIG ENABLED', () {
    test('is parsed from MDMS', () {
      final parsed = model.BackgroundServiceConfig.fromJson({
        ..._baseJson,
        'ENABLED': false,
      });
      expect(parsed.enabled, false);
    });

    test('is optional so existing MDMS data still parses', () {
      final parsed = model.BackgroundServiceConfig.fromJson(_baseJson);
      expect(parsed.enabled, isNull);
    });
  });

  group('isBackgroundServiceEnabled', () {
    test('defaults to enabled when config or flag is missing', () {
      expect(isBackgroundServiceEnabled(null), true);
      expect(
        isBackgroundServiceEnabled(
          schema.AppConfiguration()..backgroundServiceConfig = null,
        ),
        true,
      );
      expect(isBackgroundServiceEnabled(_configWith(null)), true);
    });

    test('follows the MDMS flag when set', () {
      expect(isBackgroundServiceEnabled(_configWith(true)), true);
      expect(isBackgroundServiceEnabled(_configWith(false)), false);
    });
  });
}
