# Semantics-identifier patches (app code, deliberately uncommitted)

These patches add stable `Semantics(identifier:)` wrappers so Maestro can select
elements by Android `resource-id` (e.g. `id: "login_userId"`) instead of localized
text — selectors then survive campaign label changes. They are **not committed by
policy**; this folder is their shareable home.

| Patch | Touches | What it adds |
|---|---|---|
| `01-flow-builder.patch` | `packages/digit_flow_builder` (+2 new files) | One wrapper in `FlowWidgetFactory.build()` — covers EVERY config-driven widget. Id = `<stateKey>_<fieldKey>` from the config's `key`/`fieldName`; buttons fall back to their label localization CODE; widgets without keys get no id. Includes the pure helper + 11 unit tests. |
| `02-forms-engine.patch` | `packages/digit_forms_engine` | Wraps every FORM-screen reactive field; id = `formControlName`. |
| `03-login.patch` | `apps/.../lib/pages/login.dart` | `login_userId`, `login_password`, `login_submit`. |
| `04-boundary.patch` | `apps/.../lib/pages/boundary_selection.dart` | `boundary_<levelName>` per level dropdown, `boundary_submit`. |

## Apply (from the repo root)

```
git apply qa/testkit/patches/01-flow-builder.patch
git apply qa/testkit/patches/02-forms-engine.patch
git apply qa/testkit/patches/03-login.patch
git apply qa/testkit/patches/04-boundary.patch
```

Then rebuild the APK — the ids only exist in builds made after applying.

## Revert

```
git checkout -- packages/digit_flow_builder/lib/widgets/flow_widget_interface.dart
git checkout -- packages/digit_forms_engine/lib/widgets/base_reactive_field_wrapper.dart
git checkout -- apps/health_campaign_field_worker_app/lib/pages/login.dart
git checkout -- apps/health_campaign_field_worker_app/lib/pages/boundary_selection.dart
rm packages/digit_flow_builder/lib/utils/semantics_identifier.dart
rm packages/digit_flow_builder/test/semantics_identifier_test.dart
```

## Rules

- **Keep these out of unrelated commits.** Before committing other work, revert
  the four tracked files (commands above) or stage selectively — then re-apply.
- After editing any of the touched files, regenerate the affected patch:
  `git diff -- <path> > qa/testkit/patches/<nn>-<name>.patch`
  (for the two new files, `git add -N` them first, and `git reset` after).
- Consent checkbox has NO id on purpose — it lives in the pub-hosted
  digit_ui_components package; flows keep its text selector `(?s)By clicking.*`.
- Verified 2026-08-21: `flutter analyze` — 0 errors app-wide, 0 new issues in
  touched files; 11/11 helper unit tests pass
  (`flutter test test/semantics_identifier_test.dart` in digit_flow_builder).
  On-device resource-id confirmation is still pending (needs a rebuilt APK +
  `maestro hierarchy`).
