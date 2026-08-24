// Runs every config invariant from the lint engine against the REAL local
// configs (assets/configs — a clone of HCM-SOLUTION-CONFIG; refresh it
// before trusting verdicts) and the real code registries.
//
// One test() per invariant so a red run names the broken invariant directly.
// Fixes belong in HCM-SOLUTION-CONFIG or in code — never in this kit.
//
// Scenario sources: scenarios/config/*.md

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../lint/config_lint_engine.dart';

const _jsonDir = 'assets/configs/json';
const _configsRoot = 'assets/configs';
const _transformerPath =
    '../../packages/digit_flow_builder/lib/data/transformer_config.dart';

/// fns registered with non-literal names would be missed by the textual
/// scan — add them here if one ever appears.
const extraRegisteredFns = <String>{};

/// Navigation targets that resolve at runtime even though no local config
/// defines them (e.g. screens from a config served only by MDMS). Every
/// entry needs a comment saying where the screen actually lives.
const externalScreens = <String>{};

/// Screens intentionally entered only from app code, never from another
/// config screen. Every entry needs a comment naming the code entry point.
const appEntryScreens = <String>{};

/// actionTypes handled by code the textual scan cannot see. Every entry
/// needs a comment naming the handler.
const extraActionTypes = <String>{};

void main() {
  late final ConfigSet flowConfigs = loadConfigDocs(_jsonDir);
  late final ConfigSet rootConfigs = loadConfigDocs(_configsRoot);

  void expectClean(List<String> violations, String hint) {
    expect(
      violations,
      isEmpty,
      reason: 'Config invariant violated:\n${violations.join('\n')}\n$hint',
    );
  }

  bool skipIfNoConfigs() {
    if (flowConfigs.isEmpty) {
      markTestSkipped(
        'No local configs at $_jsonDir — pull HCM-SOLUTION-CONFIG '
        '(git pull in assets/configs) before trusting this lint.',
      );
      return true;
    }
    return false;
  }

  test('cycle-verdict configs stamp cycleIndex usably', () {
    if (skipIfNoConfigs()) return;
    expectClean(
      lintCycleIndexStamp(flowConfigs),
      'Per-cycle verdicts (ineligibility) must carry the cycle they were '
      'made in; fix in HCM-SOLUTION-CONFIG, then refresh the local clone.',
    );
  });

  test('FORM screens never feed contextData.* to the transformer', () {
    if (skipIfNoConfigs()) return;
    expectClean(
      lintFormContextData(flowConfigs),
      'The FORM submit context is only {formData, navigation, entities}.',
    );
  });

  test('every FETCH configName exists and critical keys are mapped', () {
    if (skipIfNoConfigs()) return;
    final transformer = File(_transformerPath);
    if (!transformer.existsSync()) {
      markTestSkipped(
        '$_transformerPath not found — run the kit from the app directory '
        '(apps/health_campaign_field_worker_app).',
      );
      return;
    }
    expectClean(
      lintTransformerMapping(flowConfigs, transformer.readAsStringSync()),
      'A field lands only if navigation passes it AND data lists it AND the '
      'transformer MAPPING has it — this checks the third link.',
    );
  });

  test('every fn: referenced in configs is registered in code', () {
    if (skipIfNoConfigs()) return;
    final registered = collectRegisteredFnNames(['lib', '../../packages'])
      ..addAll(extraRegisteredFns);
    if (registered.isEmpty) {
      markTestSkipped(
        'No FunctionRegistry.register sites found — run the kit from the '
        'app directory.',
      );
      return;
    }
    expectClean(
      lintUnregisteredFns(flowConfigs, registered),
      'An unregistered fn silently hides gated widgets or blanks TEMPLATE '
      'bodies. Ship the app registering the fn BEFORE the config using it.',
    );
  });

  test('no whitespace-only UI text in configs', () {
    if (skipIfNoConfigs()) return;
    expectClean(
      lintWhitespaceOnlyText(flowConfigs),
      'A single-space value renders invisible and defeats isNotEmpty '
      'guards (only trim().isNotEmpty survives).',
    );
  });

  test('every NAVIGATION target is a real screen (flow wiring end-to-end)',
      () {
    if (skipIfNoConfigs()) return;
    expectClean(
      lintNavigationTargets(flowConfigs, allow: externalScreens),
      'An unresolved target shows "No route found" and goes nowhere — a '
      'dead button in the journey.',
    );
  });

  test('every actionType in configs has a handler', () {
    if (skipIfNoConfigs()) return;
    final known = collectKnownActionTypes(['lib', '../../packages'])
      ..addAll(extraActionTypes);
    if (known.isEmpty) {
      markTestSkipped(
        'No actionType handlers found — run the kit from the app directory.',
      );
      return;
    }
    expectClean(
      lintUnknownActionTypes(flowConfigs, known),
      'Unknown actionTypes are silent no-ops — the step simply does not '
      'happen at runtime.',
    );
  });

  test('no orphan screens (defined but unreachable from anywhere)', () {
    if (skipIfNoConfigs()) return;
    expectClean(
      lintOrphanScreens(flowConfigs, allow: appEntryScreens),
      'A screen nothing references is dead weight or a broken entry point.',
    );
  });

  test('no blank messages in localization dumps (if any are present)', () {
    final all = ConfigSet(
      [...flowConfigs.docs, ...rootConfigs.docs],
      const [],
    );
    if (!hasLocalizationDocs(all)) {
      markTestSkipped(
        'No localization dump in $_configsRoot — drop a scraped '
        '[{code, message, module, ...}] JSON there to lint campaign '
        'localization for blank messages.',
      );
      return;
    }
    expectClean(
      lintBlankLocalization(all),
      'A record that EXISTS with ""/" " shadows base-module text app-wide; '
      'campaign modules (hcm-*-CMP-<id>) shadow hcm-base-*.',
    );
  });
}
