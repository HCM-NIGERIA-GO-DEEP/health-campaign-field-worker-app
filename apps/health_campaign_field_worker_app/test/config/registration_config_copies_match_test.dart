import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

/// The REGISTRATION flow exists twice: the Dart copy the app falls back to
/// (`sampleFlows`, home.dart) and `REGISTRATION.json` in the config repo,
/// which is what gets uploaded to the server. On 2026-11-25 the JSON was 87
/// values behind the Dart copy - it had no head-edit route, the old 10-digit
/// phone rule, no delivery scan check - so a server record built from it
/// would have undone fixes the APK already carried.
///
/// A change to one copy must be made in the other. Key order is ignored.
void main() {
  test('REGISTRATION.json equals the Dart copy', () {
    final dart = jsonDecode(jsonEncode(sampleFlows)) as Map<String, dynamic>;
    final file = jsonDecode(
      File('assets/configs/json/REGISTRATION.json')
          .readAsStringSync()
          .replaceFirst('﻿', ''),
    ) as Map<String, dynamic>;

    final differences = <String>[];
    void walk(dynamic a, dynamic b, String path) {
      if (differences.length >= 20) return;
      if (a is Map && b is Map) {
        for (final key in {...a.keys, ...b.keys}) {
          if (!a.containsKey(key)) {
            differences.add('$path.$key: only in REGISTRATION.json');
          } else if (!b.containsKey(key)) {
            differences.add('$path.$key: only in the Dart copy');
          } else {
            walk(a[key], b[key], '$path.$key');
          }
        }
      } else if (a is List && b is List) {
        if (a.length != b.length) {
          differences.add('$path: ${a.length} items in Dart, ${b.length} in JSON');
        }
        for (var i = 0; i < a.length && i < b.length; i++) {
          walk(a[i], b[i], '$path[$i]');
        }
      } else if (a != b) {
        differences.add('$path: Dart "$a", JSON "$b"');
      }
    }

    final dartFlows = {
      for (final f in dart['flows'] as List) (f as Map)['name']: f,
    };
    final fileFlows = {
      for (final f in file['flows'] as List) (f as Map)['name']: f,
    };
    expect(fileFlows.keys.toList(), dartFlows.keys.toList());
    for (final name in dartFlows.keys) {
      walk(dartFlows[name], fileFlows[name], '$name');
    }
    walk({...dart}..remove('flows'), {...file}..remove('flows'), '');

    expect(differences, isEmpty,
        reason: 'first differences (at most 20):\n${differences.join('\n')}');
  });
}
