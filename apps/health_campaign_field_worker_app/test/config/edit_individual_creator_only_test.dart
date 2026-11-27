import 'dart:convert';
import 'dart:io';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart';
import 'package:digit_flow_builder/utils/conditional_evaluator.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/sampleJsonConfigs/registration_flows.dart';

/// Liberia QA: an Individual update is rejected by the server
/// (INVALID_USER_ID on the beneficiary id) unless the user who created the
/// individual sends it. So Edit Individual on Household Overview is disabled
/// for everyone except the creator. Runs the real `disableEdit` through the
/// shipped rule string, in both config copies.

const _rule =
    '{{fn:disableEdit(item.task, item.hFReferral, item.individual)}}==true';
const _oldRule = '{{fn:disableEdit(item.task, item.hFReferral)}}==true';

void _login(String uuid) {
  FlowBuilderSingleton().setInitialData(
    loggedInUserUuid: uuid,
    maxRadius: 0,
    projectId: 'project',
    selectedBeneficiaryType: BeneficiaryType.household,
    projectType: null,
    selectedProject: ProjectModel(id: 'project', name: 'Project'),
    loggedInUser: UserModel(uuid: uuid),
  );
}

IndividualModel _individual({String? audit, String? clientAudit}) =>
    IndividualModel(
      clientReferenceId: 'individual-1',
      auditDetails: audit == null
          ? null
          : AuditDetails(createdBy: audit, createdTime: 1),
      clientAuditDetails: clientAudit == null
          ? null
          : ClientAuditDetails(createdBy: clientAudit, createdTime: 1),
    );

bool _disabled(
  String rule, {
  Object? individual,
  List<Object> tasks = const [],
}) =>
    ConditionalEvaluator.evaluate(rule, <String, dynamic>{
      'item': {
        'task': tasks,
        'hFReferral': const [],
        if (individual != null) 'individual': individual,
      },
      'contextData': const [],
    }) ==
    true;

/// The `disabled` rule of every Edit Individual button in [node].
List<String> _editRules(dynamic node) {
  final found = <String>[];
  void walk(dynamic n) {
    if (n is Map) {
      if (n['label'] == 'REGISTRATION_EDIT_INDIVIDUAL_BUTTON_LABEL') {
        found.add(n['disabled'].toString());
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(node);
  return found;
}

void main() {
  setUpAll(() {
    initializeMappers();
    initializeFunctionRegistry();
  });

  setUp(() => _login('registrar-a'));

  test('both config copies ship the creator rule on Edit Individual', () {
    final bundled = jsonDecode(utf8
        .decode(File('assets/configs/json/REGISTRATION.json').readAsBytesSync())
        .replaceFirst('﻿', ''));
    for (final rules in [_editRules(sampleFlows), _editRules(bundled)]) {
      expect(rules, isNotEmpty);
      expect(rules, everyElement(_rule));
    }
  });

  test('the creator can edit', () {
    expect(_disabled(_rule, individual: [_individual(audit: 'registrar-a')]),
        isFalse);
  });

  test('another user cannot edit', () {
    expect(_disabled(_rule, individual: [_individual(audit: 'registrar-a')]),
        isFalse);
    _login('registrar-b');
    expect(_disabled(_rule, individual: [_individual(audit: 'registrar-a')]),
        isTrue);
  });

  test('the creator is read from clientAuditDetails when there is no audit',
      () {
    final individual = [_individual(clientAudit: 'registrar-a')];
    expect(_disabled(_rule, individual: individual), isFalse);
    _login('registrar-b');
    expect(_disabled(_rule, individual: individual), isTrue);
  });

  test('auditDetails (the server creator) wins over clientAuditDetails', () {
    final individual = [
      _individual(audit: 'registrar-a', clientAudit: 'registrar-b')
    ];
    expect(_disabled(_rule, individual: individual), isFalse);
    _login('registrar-b');
    expect(_disabled(_rule, individual: individual), isTrue);
  });

  test('a record as a map (not a model) is read the same way', () {
    final individual = [_individual(audit: 'registrar-a').toMap()];
    expect(_disabled(_rule, individual: individual), isFalse);
    _login('registrar-b');
    expect(_disabled(_rule, individual: individual), isTrue);
  });

  test('an unknown creator, a missing individual or no user stays enabled',
      () {
    _login('registrar-b');
    expect(_disabled(_rule, individual: [_individual()]), isFalse);
    expect(_disabled(_rule, individual: const []), isFalse);
    expect(_disabled(_rule), isFalse);
    _login('');
    expect(_disabled(_rule, individual: [_individual(audit: 'registrar-a')]),
        isFalse);
  });

  test('the creator is still blocked after a delivery (old rule kept)', () {
    final delivered = [
      {'status': 'ADMINISTRATION_SUCCESS'}
    ];
    expect(
        _disabled(_rule,
            individual: [_individual(audit: 'registrar-a')], tasks: delivered),
        isTrue);
  });

  test('the old two-argument rule (older config) never blocks by creator', () {
    _login('registrar-b');
    expect(_disabled(_oldRule, individual: [_individual(audit: 'registrar-a')]),
        isFalse);
  });
}
