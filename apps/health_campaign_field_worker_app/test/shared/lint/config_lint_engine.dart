// Pure-Dart config lint engine — imports NO app code so it compiles and runs
// on every branch, including ones with baseline compile errors in lib/.
//
// Each invariant is a pure function returning a list of human-readable
// violations. Test wrappers (test/config/) run them against the real configs;
// self-tests (test/lint_selftest/) prove each one fires on a bad fixture.
//
// To add a new invariant:
//   1. Write a `List<String> lintYourInvariant(...)` here (pure — takes
//      parsed docs / source text, no I/O beyond what the loaders provide).
//   2. Add a bad + good fixture case in test/lint_selftest/.
//   3. Add a test() in test/config/config_invariants_test.dart.
//   4. Add a scenario file under scenarios/config/.

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Loading & walking
// ---------------------------------------------------------------------------

class ConfigDoc {
  final String path;
  final dynamic root;

  ConfigDoc(this.path, this.root);
}

class ConfigSet {
  final List<ConfigDoc> docs;
  final List<String> parseErrors;

  ConfigSet(this.docs, this.parseErrors);

  bool get isEmpty => docs.isEmpty && parseErrors.isEmpty;
}

/// Loads every *.json under [dirPath] (non-recursive). Dart's file reader
/// strips UTF-8 BOMs (the configs repo files carry them). Parse failures are
/// reported, not thrown — a malformed config must surface as a violation.
ConfigSet loadConfigDocs(String dirPath) {
  final dir = Directory(dirPath);
  final docs = <ConfigDoc>[];
  final errors = <String>[];
  if (!dir.existsSync()) return ConfigSet(docs, errors);
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    try {
      docs.add(ConfigDoc(file.path, jsonDecode(file.readAsStringSync())));
    } on FormatException catch (e) {
      errors.add('${file.path}: not valid JSON (${e.message})');
    }
  }
  return ConfigSet(docs, errors);
}

/// Depth-first visit of every node in a decoded JSON tree.
void walkJson(dynamic node, void Function(dynamic node) visit) {
  visit(node);
  if (node is Map) {
    for (final value in node.values) {
      walkJson(value, visit);
    }
  } else if (node is List) {
    for (final item in node) {
      walkJson(item, visit);
    }
  }
}

/// Collects every map in the tree satisfying [predicate].
List<Map<String, dynamic>> collectMaps(
  dynamic root,
  bool Function(Map<String, dynamic> m) predicate,
) {
  final out = <Map<String, dynamic>>[];
  walkJson(root, (node) {
    if (node is Map<String, dynamic> && predicate(node)) out.add(node);
  });
  return out;
}

/// FETCH_TRANSFORMER_CONFIG `properties` maps ({data, configName, ...}).
List<Map<String, dynamic>> fetchTransformerBlocks(dynamic root) => collectMaps(
      root,
      (m) =>
          m['actionType'] == 'FETCH_TRANSFORMER_CONFIG' &&
          m['properties'] is Map<String, dynamic>,
    ).map((m) => m['properties'] as Map<String, dynamic>).toList();

/// The screens ("flows") of a config document, or empty if not flow-shaped.
List<Map<String, dynamic>> screensOf(ConfigDoc doc) {
  final root = doc.root;
  if (root is! Map<String, dynamic>) return const [];
  final flows = root['flows'];
  if (flows is! List) return const [];
  return flows.whereType<Map<String, dynamic>>().toList();
}

// ---------------------------------------------------------------------------
// Invariant: cycle-verdict configs must stamp cycleIndex usably
// (July-20 fix; reappeared on taraba 2026-08-06 — config fixes don't
// propagate between campaigns)
// ---------------------------------------------------------------------------

/// configNames whose tasks record per-cycle verdicts — extend this list when
/// a new per-cycle transformer config is introduced.
const cycleStampedConfigNames = ['ineligibleConfig'];

List<String> lintCycleIndexStamp(ConfigSet configs) {
  final violations = <String>[...configs.parseErrors];
  for (final doc in configs.docs) {
    final blocks = fetchTransformerBlocks(doc.root)
        .where((p) => cycleStampedConfigNames.contains(p['configName']));
    for (final (i, block) in blocks.indexed) {
      final where = '${doc.path}: ${block['configName']} block #${i + 1}';
      final data = block['data'];
      if (data is! List) {
        violations.add('$where has no "data" list');
        continue;
      }
      final entry = data
          .whereType<Map<String, dynamic>>()
          .where((e) => e['key'] == 'cycleIndex')
          .firstOrNull;
      if (entry == null) {
        violations.add(
          '$where does not stamp cycleIndex — ineligible children will stay '
          'blocked in later cycles. Add {"key": "cycleIndex", "value": '
          '"{{fn:getCurrentCycleIndex()}}"}',
        );
      } else if ('${entry['value']}'.contains('contextData.')) {
        violations.add(
          '$where stamps cycleIndex from contextData.* — this resolves null '
          'in the FORM submit context and the transformer drops the field. '
          'Use {{fn:getCurrentCycleIndex()}} or navigation.*',
        );
      }
    }
  }
  return violations;
}

// ---------------------------------------------------------------------------
// Invariant: FETCH_TRANSFORMER_CONFIG data on FORM screens must not read
// contextData.* (form submit context is only {formData, navigation,
// entities} — contextData resolves null and the field is silently dropped;
// ORS cycleIndex audit, 2026-07-21)
// ---------------------------------------------------------------------------

List<String> lintFormContextData(ConfigSet configs) {
  final violations = <String>[];
  for (final doc in configs.docs) {
    for (final screen in screensOf(doc)) {
      if (screen['screenType'] != 'FORM') continue;
      for (final block in fetchTransformerBlocks(screen)) {
        final data = block['data'];
        if (data is! List) continue;
        for (final e in data.whereType<Map<String, dynamic>>()) {
          final value = '${e['value']}';
          if (value.contains('contextData.')) {
            violations.add(
              '${doc.path}: FORM screen "${screen['name']}", '
              'config "${block['configName']}", key "${e['key']}" reads '
              '$value — contextData.* is null in the FORM submit context, '
              'the transformer will silently drop this field. Use '
              '{{fn:...}} or navigation.*',
            );
          }
        }
      }
    }
  }
  return violations;
}

// ---------------------------------------------------------------------------
// Invariant: transformer three-link check. Every configName referenced by a
// FETCH block must exist in transformer_config.dart, and critical data keys
// must have a "__context:<key>" mapping in that config's section — a field
// lands only if navigation passes it AND data lists it AND the mapping has
// it (orsDelivery had links 1+2 but not 3; ORS tasks silently unstamped)
// ---------------------------------------------------------------------------

/// Data keys that MUST be mapped when a FETCH block passes them — extend
/// when a new must-land field is introduced.
const criticalMappedKeys = ['cycleIndex'];

/// Splits transformer_config.dart's `jsonConfig` map into top-level named
/// sections (keys at indent 2: `  "name": {`).
Map<String, String> transformerSections(String source) {
  final sections = <String, String>{};
  final matches =
      RegExp(r'^  "([A-Za-z0-9_]+)": \{', multiLine: true).allMatches(source);
  final list = matches.toList();
  for (var i = 0; i < list.length; i++) {
    final end = i + 1 < list.length ? list[i + 1].start : source.length;
    sections[list[i].group(1)!] = source.substring(list[i].start, end);
  }
  return sections;
}

List<String> lintTransformerMapping(
  ConfigSet configs,
  String transformerSource,
) {
  final violations = <String>[];
  final sections = transformerSections(transformerSource);
  for (final doc in configs.docs) {
    for (final block in fetchTransformerBlocks(doc.root)) {
      final name = block['configName'];
      if (name is! String || name.isEmpty) continue;
      final section = sections[name];
      if (section == null) {
        violations.add(
          '${doc.path}: FETCH references configName "$name" which does not '
          'exist in transformer_config.dart — the fetch will fail at '
          'runtime (or the name is a typo)',
        );
        continue;
      }
      final data = block['data'];
      if (data is! List) continue;
      for (final e in data.whereType<Map<String, dynamic>>()) {
        final key = e['key'];
        if (key is! String || !criticalMappedKeys.contains(key)) continue;
        if (!section.contains('__context:$key')) {
          violations.add(
            '${doc.path}: config "$name" passes critical key "$key" but the '
            'transformer section has no "__context:$key" mapping — the '
            'field is passed and listed but never lands on the entity '
            '(the orsDelivery three-link bug)',
          );
        }
      }
    }
  }
  return violations;
}

// ---------------------------------------------------------------------------
// Invariant: every fn: referenced in configs is registered in code. An
// unknown fn makes gated widgets silently disappear (working-hours gate:
// "unknown fn hides both twins") or blanks a TEMPLATE screen body.
// ---------------------------------------------------------------------------

final _fnRef = RegExp(r'fn:([A-Za-z0-9_]+)');
final _fnRegistration = RegExp(
  r'''FunctionRegistry\s*\.\s*register\s*\(\s*['"]([^'"]+)['"]''',
);

/// Non-generated, non-test dart files under [roots].
Iterable<File> dartSourceFiles(List<String> roots) sync* {
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final p = entity.path.replaceAll('\\', '/');
      if (!p.endsWith('.dart')) continue;
      if (p.endsWith('.g.dart') ||
          p.endsWith('.freezed.dart') ||
          p.endsWith('.mapper.dart')) {
        continue;
      }
      if (p.contains('/test/') ||
          p.contains('/build/') ||
          p.contains('/.dart_tool/')) {
        continue;
      }
      yield entity;
    }
  }
}

/// Scans dart sources under [roots] for literal FunctionRegistry.register
/// calls. Generated and test files are skipped. Purely textual — a fn
/// registered with a computed name will be missed (none exist today; if one
/// appears, add its name to [extraRegisteredFns] in the test wrapper).
Set<String> collectRegisteredFnNames(List<String> roots) {
  final names = <String>{};
  for (final file in dartSourceFiles(roots)) {
    final content = file.readAsStringSync();
    if (!content.contains('FunctionRegistry')) continue;
    for (final m in _fnRegistration.allMatches(content)) {
      names.add(m.group(1)!);
    }
  }
  return names;
}

List<String> lintUnregisteredFns(ConfigSet configs, Set<String> registered) {
  final violations = <String>[];
  final reported = <String>{};
  for (final doc in configs.docs) {
    walkJson(doc.root, (node) {
      if (node is! String) return;
      for (final m in _fnRef.allMatches(node)) {
        final name = m.group(1)!;
        if (registered.contains(name) || !reported.add(name)) continue;
        violations.add(
          '${doc.path}: references fn:$name which is not registered '
          'anywhere in code — widgets gated on it silently disappear and '
          'TEMPLATE bodies can blank. Register it before shipping this '
          'config (config must ship AFTER the app that registers its fns)',
        );
      }
    });
  }
  return violations;
}

// ---------------------------------------------------------------------------
// Invariant: no whitespace-only UI text in configs. A single-space value
// defeats every isNotEmpty guard (only trim().isNotEmpty survives) and
// renders as invisible text (Manage Stock blank-texts, 2026-08-06).
// ---------------------------------------------------------------------------

const _textKeys = {
  'label',
  'text',
  'message',
  'title',
  'hint',
  'hintText',
  'heading',
  'subHeading',
  'description',
  'buttonText',
  'errorMessage',
};

List<String> lintWhitespaceOnlyText(ConfigSet configs) {
  final violations = <String>[];
  for (final doc in configs.docs) {
    walkJson(doc.root, (node) {
      if (node is! Map<String, dynamic>) return;
      for (final entry in node.entries) {
        final value = entry.value;
        if (_textKeys.contains(entry.key) &&
            value is String &&
            value.isNotEmpty &&
            value.trim().isEmpty) {
          violations.add(
            '${doc.path}: "${entry.key}" is whitespace-only '
            '(${value.length} space(s)) — renders invisible and defeats '
            'isNotEmpty guards. Use a real value or remove the key',
          );
        }
      }
    });
  }
  return violations;
}

// ---------------------------------------------------------------------------
// Invariant: no blank localization messages. A record that EXISTS with ""
// or " " shadows the base-module text app-wide (campaign modules
// hcm-*-CMP-<id> shadow hcm-base-*; 82 blank records found 2026-08-06).
// Runs over any localization-shaped JSON dropped into the configs folder
// (a list of {code, message, ...} entries, at root or under "messages").
// ---------------------------------------------------------------------------

List<Map<String, dynamic>>? _localizationEntries(dynamic root) {
  final list = root is List
      ? root
      : (root is Map<String, dynamic> ? root['messages'] : null);
  if (list is! List) return null;
  final entries = list
      .whereType<Map<String, dynamic>>()
      .where((e) => e.containsKey('code') && e.containsKey('message'))
      .toList();
  return entries.isEmpty ? null : entries;
}

List<String> lintBlankLocalization(ConfigSet configs) {
  final violations = <String>[];
  for (final doc in configs.docs) {
    final entries = _localizationEntries(doc.root);
    if (entries == null) continue; // not a localization dump
    for (final e in entries) {
      final message = e['message'];
      if (message is String && message.trim().isEmpty) {
        violations.add(
          '${doc.path}: code "${e['code']}"'
          '${e['module'] != null ? ' (module ${e['module']})' : ''} has a '
          'blank message ("${message.replaceAll(' ', '·')}") — it shadows '
          'the base-module text and renders invisible',
        );
      }
    }
  }
  return violations;
}

/// True if any doc looks like a localization dump (used to skip vs run).
bool hasLocalizationDocs(ConfigSet configs) =>
    configs.docs.any((d) => _localizationEntries(d.root) != null);

// ---------------------------------------------------------------------------
// Flow-graph invariants — end-to-end wiring of each config-driven journey
// (registration, delivery, HF referral, inventory, ...). The engine resolves
// NAVIGATION names via FlowRegistry (all screens across all loaded configs,
// plus the special HOME); an unresolved name shows an error toast and goes
// NOWHERE (navigation_service.dart "No route found for key"), and an
// unknown actionType is a silent no-op (action_executor_registry.dart
// "No executor found") — both are invisible in the config diff.
// ---------------------------------------------------------------------------

/// actionType compared/registered as an ALL-CAPS literal near "actionType"
/// or in a registry register('X', ...) call. Uppercase-only keeps fn-registry
/// names (camelCase) out.
final _actionTypeNearLiteral = RegExp(r"actionType[^\n]{0,24}'([A-Z][A-Z_]{2,})'");
final _actionTypeRegistered = RegExp(r"register\(\s*'([A-Z][A-Z_]{2,})'");

/// Textually collects every actionType the engine/app can handle.
Set<String> collectKnownActionTypes(List<String> roots) {
  final types = <String>{};
  for (final file in dartSourceFiles(roots)) {
    final content = file.readAsStringSync();
    if (!content.contains('actionType') && !content.contains('register(')) {
      continue;
    }
    for (final m in _actionTypeNearLiteral.allMatches(content)) {
      types.add(m.group(1)!);
    }
    for (final m in _actionTypeRegistered.allMatches(content)) {
      types.add(m.group(1)!);
    }
  }
  return types;
}

List<String> lintUnknownActionTypes(
  ConfigSet configs,
  Set<String> known, {
  Set<String> allow = const {},
}) {
  final violations = <String>[];
  for (final doc in configs.docs) {
    final reported = <String>{};
    walkJson(doc.root, (node) {
      if (node is! Map<String, dynamic>) return;
      final type = node['actionType'];
      if (type is! String || type.contains('{{')) return;
      if (known.contains(type) || allow.contains(type)) return;
      if (!reported.add(type)) return;
      violations.add(
        '${doc.path}: actionType "$type" has no executor — the engine '
        'silently no-ops it (action_executor_registry: "No executor found"). '
        'Expressions are not evaluated in actionType; use a real type or '
        'split into conditioned actions',
      );
    });
  }
  return violations;
}

/// Screen names across ALL docs — NAVIGATION resolves globally.
Set<String> allScreenNames(ConfigSet configs) => {
      for (final doc in configs.docs)
        for (final screen in screensOf(doc))
          if (screen['name'] is String) screen['name'] as String,
    };

List<String> lintNavigationTargets(
  ConfigSet configs, {
  Set<String> allow = const {},
}) {
  final violations = <String>[];
  final known = {...allScreenNames(configs), 'HOME', ...allow};
  for (final doc in configs.docs) {
    void checkIn(dynamic subtree, String screenLabel) {
      walkJson(subtree, (node) {
        if (node is! Map<String, dynamic>) return;
        if (node['actionType'] != 'NAVIGATION') return;
        final props = node['properties'];
        if (props is! Map<String, dynamic>) return;
        for (final key in const ['name', 'popUntilPageName']) {
          final target = props[key];
          if (target is! String || target.isEmpty || target.contains('{{')) {
            continue;
          }
          if (known.contains(target)) continue;
          violations.add(
            '${doc.path}: screen "$screenLabel" navigates to "$target" '
            '($key) which is no screen in any loaded config — at runtime '
            'this shows "No route found" and goes nowhere. Fix the name, '
            'or if the screen comes from a config not present locally, '
            'add it to the allowlist with a comment',
          );
        }
      });
    }

    final screens = screensOf(doc);
    if (screens.isEmpty) {
      checkIn(doc.root, '?');
    } else {
      for (final screen in screens) {
        checkIn(screen, '${screen['name']}');
      }
    }
  }
  return violations;
}

/// popUntilAndPush stops popping AT the popUntilPageName screen
/// (navigation_service.dart _popUntilPage), so pushing that SAME screen
/// lands the fresh instance on top of the stale old one — Android back then
/// reveals the old instance with its pre-flow state (SMC ineligible flow:
/// overview-under-overview, QA bug fixed 2026-08-21). Pop until the screen
/// BELOW the one being refreshed (the searchBeneficiary pattern) or use
/// popUntilAndReplace, which pops the old target before pushing.
List<String> lintPushOverSelf(
  ConfigSet configs, {
  Set<String> allow = const {},
}) {
  final violations = <String>[];
  for (final doc in configs.docs) {
    walkJson(doc.root, (node) {
      if (node is! Map<String, dynamic>) return;
      if (node['actionType'] != 'NAVIGATION') return;
      final props = node['properties'];
      if (props is! Map<String, dynamic>) return;
      final mode = props['navigationMode'];
      final normalizedMode =
          mode is String ? mode.toLowerCase().replaceAll('_', '') : '';
      if (normalizedMode != 'popuntilandpush') return;
      final name = props['name'];
      if (name is! String || name.isEmpty || name.contains('{{')) return;
      if (name != props['popUntilPageName'] || allow.contains(name)) return;
      violations.add(
        '${doc.path}: NAVIGATION pushes "$name" with popUntilAndPush + '
        'popUntilPageName "$name" — popUntil stops AT the old instance, so '
        'the fresh push lands on top of it and Android back reveals the '
        'stale screen (the ineligible-flow overview bug). Pop until the '
        'screen below it instead, or use popUntilAndReplace',
      );
    });
  }
  return violations;
}

/// A screen defined in some config but never referenced by name anywhere
/// else (any string value in any doc, or an initialPage) is dead weight —
/// either a removed feature or a broken entry point.
List<String> lintOrphanScreens(
  ConfigSet configs, {
  Set<String> allow = const {},
}) {
  final violations = <String>[];
  final initialPages = <String>{
    for (final doc in configs.docs)
      if (doc.root is Map<String, dynamic> &&
          (doc.root as Map<String, dynamic>)['initialPage'] is String)
        (doc.root as Map<String, dynamic>)['initialPage'] as String,
  };
  // Count exact string-value occurrences across every doc. A screen's own
  // definition contributes exactly one (its "name" field).
  final counts = <String, int>{};
  for (final doc in configs.docs) {
    walkJson(doc.root, (node) {
      if (node is String) counts[node] = (counts[node] ?? 0) + 1;
    });
  }
  for (final doc in configs.docs) {
    for (final screen in screensOf(doc)) {
      final name = screen['name'];
      if (name is! String || allow.contains(name)) continue;
      if (initialPages.contains(name)) continue;
      if ((counts[name] ?? 0) > 1) continue;
      violations.add(
        '${doc.path}: screen "$name" is defined but referenced nowhere '
        '(no navigation reaches it and it is no initialPage) — dead screen, '
        'or its entry point was removed/renamed',
      );
    }
  }
  return violations;
}
