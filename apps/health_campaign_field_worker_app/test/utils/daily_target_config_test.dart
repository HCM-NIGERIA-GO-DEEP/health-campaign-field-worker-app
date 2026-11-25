import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';
import 'package:health_campaign_field_worker_app/utils/daily_target_config.dart';

void main() {
  double? read(
    dynamic config, {
    bool isRegistrar = false,
    bool isDistributor = false,
  }) =>
      dailyTargetFromFlowConfig(
        config,
        isRegistrar: isRegistrar,
        isDistributor: isDistributor,
      );

  group('dailyTargetFromFlowConfig - role', () {
    const config = {
      'dailyTarget': {'registrar': 40, 'distributor': 90},
    };

    test('a registrar-only user gets the registrar target', () {
      expect(read(config, isRegistrar: true), 40);
    });

    test('a distributor-only user gets the distributor target', () {
      expect(read(config, isDistributor: true), 90);
    });

    test(
        'a combined user gets the distributor target, because the bar counts '
        'deliveries for them', () {
      expect(read(config, isRegistrar: true, isDistributor: true), 90);
    });

    test('a user with neither role gets the distributor target', () {
      expect(read(config), 90);
    });

    test('a missing role entry does not borrow the other role\'s value', () {
      const onlyDistributor = {
        'dailyTarget': {'distributor': 90},
      };
      expect(read(onlyDistributor, isRegistrar: true), isNull);
      expect(read(onlyDistributor, isDistributor: true), 90);
    });
  });

  group('dailyTargetFromFlowConfig - value', () {
    Map<String, dynamic> withValue(dynamic value) => {
          'dailyTarget': {'registrar': value},
        };

    test('accepts an int, a double and a numeric string', () {
      expect(read(withValue(65), isRegistrar: true), 65);
      expect(read(withValue(65.0), isRegistrar: true), 65);
      expect(read(withValue(' 65 '), isRegistrar: true), 65);
    });

    test('returns null for zero, negative, non-numeric and non-finite', () {
      for (final bad in [
        0,
        -5,
        '0',
        'abc',
        '',
        null,
        true,
        [65],
        {'value': 65},
        double.nan,
        double.infinity,
        'Infinity',
      ]) {
        expect(read(withValue(bad), isRegistrar: true), isNull,
            reason: 'value: $bad');
      }
    });
  });

  group('dailyTargetFromFlowConfig - shape', () {
    test('returns null when the config or the key is missing or mis-shaped',
        () {
      for (final config in [
        null,
        'REGISTRATION',
        <dynamic>[],
        <String, dynamic>{},
        {'dailyTarget': null},
        {'dailyTarget': 65},
        {
          'dailyTarget': [65, 65]
        },
        {
          'flows': [
            {
              'dailyTarget': {'registrar': 65}
            }
          ]
        },
      ]) {
        expect(read(config, isRegistrar: true), isNull,
            reason: 'config: $config');
      }
    });
  });

  group('shipped REGISTRATION config', () {
    final sources = <String, dynamic>{
      'Dart copy (sampleFlows)': sampleFlows,
    };
    final jsonFile = File('assets/configs/json/REGISTRATION.json');
    if (jsonFile.existsSync()) {
      sources['REGISTRATION.json'] =
          jsonDecode(utf8.decode(jsonFile.readAsBytesSync()));
    }

    sources.forEach((name, config) {
      test('$name sets 65 for the registrar and 65 for the distributor', () {
        expect(read(config, isRegistrar: true), 65);
        expect(read(config, isDistributor: true), 65);
        expect(((config as Map)['dailyTarget'] as Map).keys.toSet(),
            {'registrar', 'distributor'});
      });
    });
  });
}
