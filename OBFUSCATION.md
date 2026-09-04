# Dart Obfuscation

Why `build_obfuscated.sh` broke MDMS-driven flows, how it was fixed, and the
rules to follow so it does not happen again.

---

## 1. At a glance

| | |
|---|---|
| **Symptom** | MDMS/flow-config driven screens do nothing in obfuscated builds; fine in normal release builds |
| **Cause** | `runtimeType.toString()` used to resolve model names that configs and registries address by class name |
| **Trigger** | `flutter build --obfuscate` renames Dart classes, so that call returns e.g. `Xj` instead of `HouseholdModel` |
| **Failure mode** | Silent. Lookups miss, `orElse` branches return empty, nothing is logged |
| **Fix** | [`entityTypeName()`](packages/digit_data_model/lib/utils/entity_type_name.dart), which reads the name from the model's `dart_mappable` mapper |
| **Not involved** | R8/ProGuard, MDMS fetch and parsing, the oplog, sync-up/sync-down |

---

## 2. The failure

The flow builder is config-driven, and those configs come from MDMS. They
address models by their **Dart class name**:

```json
{
  "models": {
    "HouseholdModel": { "mappings": { "memberCount": "form.members" } },
    "IndividualModel": { "mappings": { "name.givenName": "form.firstName" } }
  },
  "fallbackFormData": "HouseholdModel"
}
```

The runtime side is keyed by those same literal names — see
`EntityModelJsonMapper.modelFactoryRegistry` in
[digit_data_converter.dart](packages/digit_flow_builder/lib/data/digit_data_converter.dart):

```dart
Map<String, ModelFactory> get modelFactoryRegistry => {
      'HouseholdModel': (json) => HouseholdModelMapper.fromJson(jsonEncode(json)),
      'IndividualModel': (json) => IndividualModelMapper.fromJson(jsonEncode(json)),
      // ...
    };
```

To join the two halves, the code asked the object what it was:

```dart
final modelType = model.runtimeType.toString();   // 'HouseholdModel'
final modelConfig = modelsConfig[modelType];
```

That is exactly what obfuscation breaks. `--obfuscate` renames classes, so
`runtimeType.toString()` returns the *mangled* name. `modelsConfig['Xj']` is
null, `modelFactoryRegistry['Xj']` is null, and the code takes its "no config
for this model" path — which is a legitimate path, so nothing throws and
nothing is logged. Form data never reaches an entity, prefill produces nothing,
and dropdowns come up empty.

### Why it looked like an MDMS problem

MDMS fetching and parsing were never affected. `MasterEnums` / `ModuleEnums`
are `@MappableEnum`s whose `@MappableValue` strings compile to literal switch
statements, and `AppConfigPrimaryWrapperModel` is freezed + `json_serializable`
with literal JSON keys. The config arrived intact every time — the app just
could not act on it.

---

## 3. What obfuscation does and does not rename

Measured on AOT snapshots built with and without `--obfuscate`, not inferred:

| Construct | Plain | Obfuscated | |
|---|---|---|---|
| `runtimeType.toString()` | `PlainModel` | `Ki` | ❌ renamed |
| `Type.toString()` | `HouseholdModel` | `Ji` | ❌ renamed |
| `Enum.name` | `household` | `household` | ✅ survives |
| `Enum.toString()` | `DataModelType.household` | `DataModelType.household` | ✅ survives |
| `values.byName('task')` | works | works | ✅ survives |
| `Type` as a `Map` key | works | works | ✅ identity, not name |
| `is` / `as` checks | works | works | ✅ identity, not name |

The short rule: **class and type *names* are renamed; enum value names, string
literals, and type *identity* are not.**

This is also why `Map<Type, T>` and `entity is HouseholdModel` are safe — they
compare type identity, never a printed name.

---

## 4. The fix

`dart_mappable` stores each model's real class name as a string literal in the
generated mapper:

```dart
// packages/digit_data_model/lib/models/entities/household.mapper.dart:251
class HouseholdModelMapper extends SubClassMapperBase<HouseholdModel> {
  @override
  final String id = 'HouseholdModel';   // literal — obfuscation does not touch it
```

[`packages/digit_data_model/lib/utils/entity_type_name.dart`](packages/digit_data_model/lib/utils/entity_type_name.dart)
reads that id:

```dart
String entityTypeName(EntityModel entity) {
  final type = entity.runtimeType;
  final cached = _entityTypeNameCache[type];
  if (cached != null) return cached;

  final name = _nameFromMapper(type) ??
      _nameFromStringify(entity) ??
      type.toString();
  _entityTypeNameCache[type] = name;

  return name;
}
```

Three details worth knowing:

**It is cached by `Type`.** A `Type` object is a stable map key under
obfuscation — only the name it *prints* changes — so the cache is both safe and
means each model class is resolved once per process.

**There are two resolution paths.** `_nameFromMapper` asks
`MapperContainer.globals.get(type)?.id`, which hits whenever the mapper is
registered (`initializeMappers()` runs at startup). `_nameFromStringify` is the
fallback: a mappable model's generated `toString()` is
`'<id>(field: value, ...)'` and calls `ensureInitialized()` on the way through,
so it recovers the name even if the mapper was not registered yet. Taking the
prefix before `(` yields the same literal.

**It replaced a hand-maintained list.** The previous partial workaround in
`digit_flow_builder/lib/utils/utils.dart` was a 19-entry chain of `is` checks
returning hardcoded strings. That worked for what it listed, but it had to be
updated by hand for every new model — and had already fallen behind:
`AttendanceRegisterModel`, `AttendeeModel` and `AttendanceLogModel` were in the
factory registry but missing from the chain, so attendance flows stayed broken
in obfuscated builds even with the workaround in place. `getEntityTypeName()`
now delegates to `entityTypeName()` and the list is gone.

### Call sites changed

| File | What was broken |
|---|---|
| [transformer_service.dart](packages/digit_data_converter/lib/src/transformer_service.dart) | 6 sites: model config matching, factory lookup, fallback-model index. This is the form → entity engine |
| [reverse_transformer_service.dart](packages/digit_data_converter/lib/src/reverse_transformer_service.dart) | Form prefill from existing entities |
| [entity_grouper.dart](packages/digit_flow_builder/lib/blocs/wrapper/entity_grouper.dart) | `groupEntitiesByType` keys — see the downstream note below |
| [entity_filter.dart](packages/digit_flow_builder/lib/blocs/wrapper/entity_filter.dart) | Relation matching against config's `entity` |
| [interpolation.dart](packages/digit_flow_builder/lib/utils/interpolation.dart) | `getEntityKey`, backing `{{HouseholdModel.address.locality}}` |
| [utils.dart](packages/digit_flow_builder/lib/utils/utils.dart) | `getEntityTypeName` now delegates |
| [flow_crud_bloc.dart](packages/digit_flow_builder/lib/blocs/flow_crud_bloc.dart) | Analytics events fired as `xj_complete` instead of `stock_reconciliation_complete` |

### One downstream effect worth calling out

Several widgets read the wrapper's grouped-entity map by literal key with a
silent empty fallback:

```dart
projectFacilities = wrapperList.firstWhere(
  (m) => m.containsKey('ProjectFacilityModel'),
  orElse: () => {'ProjectFacilityModel': []},
)['ProjectFacilityModel'];
```

Because `groupEntitiesByType` produced obfuscated keys, these always fell to
`orElse` — empty facility and product dropdowns, with no error anywhere.
Affects `stock_reconciliation_card.dart`, `custom_facility_widgets.dart` and
`custom_product_selection_card.dart`; all fixed by the grouper change.

---

## 5. Audited and found safe

Checked during the same sweep, no change needed. Recorded here so nobody has to
re-derive it:

**The oplog and sync.** This was the largest additional risk, since a mangled
type name written into Isar would corrupt sync-up and break continuity with
data written by non-obfuscated builds. It is safe:
[`OpLog.entityType`](packages/digit_data_model/lib/data/local_store/no_sql/schema/oplog.dart)
is `@Enumerated(EnumType.name)` over the `DataModelType` **enum**, Isar's
generated `_OpLogentityTypeEnumValueMap` is all literals, and `getEntity()`
dispatches on `DataModelType.name` — which survives obfuscation (§3).
`sync_up`/`sync_down` use `.key.name` and `values.indexOf`, also safe.

**Repository resolution.** `DigitCrudService.getRepositoryForEntity` uses `is`
checks plus generic `context.read<LocalRepository<D, R>>()` — type identity.

**`CrudService.searchEntities` grouping.** Result keys come from config and
drift's generated `actualTableName`, never from `runtimeType`.

**Forms engine, validators, function registry.** Literal config keys matched
against literal `case` strings on both sides.

No `dart:mirrors`, no `describeEnum`, and no exception-class-name string
matching anywhere in the repo.

**The security self-check does not interfere.** `verifyBuildTimeMitigations()`
is explicitly fire-and-forget in [main.dart](apps/health_campaign_field_worker_app/lib/main.dart);
it reports and never blocks startup or exits.

---

## 6. R8 is not the difference

`android/app/build.gradle` sets `minifyEnabled true` and
`shrinkResources true` under `buildTypes.release`, so **every**
`flutter build apk --release` already runs R8 with `proguard-rules.pro`,
whether or not `--obfuscate` was passed. The only thing `build_obfuscated.sh`
adds is Dart symbol obfuscation.

That matters twice over. It narrowed this bug to the Dart layer immediately —
if R8 were the differentiator, native plugin reflection would have been the
first suspect. And it means the script's "Security Features Enabled" banner is
misleading: `✓ Code obfuscation with R8`, `✓ Resource shrinking` and
`✓ ProGuard rules applied` describe the normal release build too. Only
`✓ fvm flutter symbol obfuscation` and `✓ Debug information removed` (from
`--split-debug-info`) are specific to this script.

---

## 7. Rules for new code

**Never call `runtimeType.toString()` or `Type.toString()` to produce a value
that anything else consumes.** Logging it is fine; comparing, keying or storing
it is not.

To get a model's name, call `entityTypeName(entity)` from `digit_data_model`
(or `getEntityTypeName`, which delegates to it). It is exported from
`package:digit_data_model/data_model.dart`.

To branch on type, use `is` or a `Map<Type, T>`. Both compare identity and are
unaffected.

To put a type name in persisted data, on the wire, or in an analytics event
name, use an enum with explicit values — `DataModelType` and the
`@MappableValue`-annotated `MasterEnums` are the patterns to copy. Enum names
survive, and explicit values make the contract visible.

Adding a new model to `modelFactoryRegistry` no longer requires touching a
second list. `entityTypeName` resolves any `@MappableClass` model
automatically.

---

## 8. Verification

`packages/digit_data_model/test/entity_type_name_test.dart` covers both
resolution paths:

```bash
cd packages/digit_data_model
~/fvm/versions/3.22.2/bin/flutter test --no-pub test/entity_type_name_test.dart
```

`--no-pub` and the explicit SDK path are needed because `fvm` is not on `PATH`,
the repo pins Flutter 3.22.2 in `.fvmrc`, and a standalone `pub get` in a
package fails on an `intl` conflict. `dart analyze lib` works with the system
SDK and needs no flags.

That test runs unobfuscated, so it proves the resolver returns the right names
but cannot prove obfuscation-resistance. The table in §3 and the resolver's
behaviour under `--obfuscate` were established separately, by compiling AOT
snapshots twice and diffing the output:

```bash
dart compile aot-snapshot -o clear.aot bin/main.dart
dart compile aot-snapshot --extra-gen-snapshot-options=--obfuscate -o obf.aot bin/main.dart
<flutter>/bin/cache/dart-sdk/bin/dartaotruntime clear.aot
<flutter>/bin/cache/dart-sdk/bin/dartaotruntime obf.aot
```

`dart compile` does not expose `--obfuscate`, hence the `gen_snapshot`
passthrough. This is the cheapest way to settle any future "is X
obfuscation-safe?" question without a device build — reach for it before
guessing.

An obfuscated APK on a real device is still the only end-to-end check. Exercise
a registration flow, stock reconciliation, and one attendance flow, since those
three cover the transformer, the wrapper grouping, and the models that the old
`is`-chain had missed.

---

## 9. Known limitations

**Log and error messages still carry mangled names.** `CrudService`'s
"No repository found for entity type: ..." warnings, `SyncError.toString()`,
`api_interceptors`, and `EntityFieldAccessor`'s error text all interpolate
`runtimeType`. Harmless to behaviour, but it makes obfuscated-build triage
harder — and `--split-debug-info` does not help, because `flutter symbolize`
de-obfuscates stack frames, not name strings baked into messages.

**One user-visible instance remains.**
[`survey_form_view.dart`](packages/survey_form/lib/pages/survey_form_view.dart)
has `orElse: () => Text(state.runtimeType.toString())`, which renders an
unhandled bloc state's class name straight to the screen — so a field worker
sees something like `Xj`. Left as-is deliberately: the right replacement (a
loader, or `SizedBox.shrink()`) is a product decision, not a mechanical one.

**Two `runtimeType.toString()` fallbacks are intentional.**
`interpolation.dart:374` and `utils.dart:701` handle values that are *not*
`EntityModel`s, where no mapper exists to ask. They are last-resort branches
after the typed path has been tried.
