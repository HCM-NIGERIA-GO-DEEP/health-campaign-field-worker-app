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
| `05-ui-components-option-ids.patch` | `packages/digit_ui_components` (VENDORED — see below) | Three changes + four widget tests. (a) `option_<code>` on every dropdown option row (single-select `DigitDropdown` + `MultiSelectDropDown` flat and nested lists) — kills the option-tap fragility class; device-verified in run -1654. (b) Multiselect panel-resurrection fix: an outside-tap dismissal is now FINAL until the next field tap (`_dismissedByOutsideTap` flag) — before, any focus re-grant (Android focus churn) silently re-inserted the panel, which then swallowed taps meant for widgets behind it (runs -1654/-1710 selected a second boundary instead of Submit). Deterministically reproduced and locked in by `multiselect_outside_tap_dismissal_test.dart`. (c) `DigitButton.semanticsIdentifier` — the button applies its id INSIDE itself so callers that cast the built widget to `DigitButton` keep working; locked in by `digit_button_identifier_test.dart` (3/3). (d) `dob_date` / `dob_years` / `dob_months` ids on `DigitDobPicker`'s inner inputs — the whole card is ONE form field, so the inner inputs carry no formControlName id; typed AGE entry (years/months) is the dialog-free automation path. (e) `RadioList.semanticsIdentifierPrefix` → `Semantics(identifier: '<prefix>_<code>')` on each radio's tappable node. A radio was previously unreachable by ANY selector: run -1214 showed the option labels absorbed into the field's merged label node (one node, `clickable=false`, whose centre lands in the gap between the two circles) and the circles themselves as bare clickable nodes with no id and no text. Locked in by `radio_option_identifier_test.dart`, which also proves the option ids survive the enclosing `Semantics(identifier: formControlName)` from patch 07. (f) `DigitCheckbox.semanticsIdentifier` — same problem, one extra twist: a *single* checkbox under the field wrapper collapses into ONE node that takes the field id, drops this one, and reports `tap=true` on a rect whose centre is the LABEL (so tapping it never toggles). Fixed with `container: true` on the inner `Semantics`, which keeps the id on the box's own 24x24 rect. `RadioList` needs no such flag — two option nodes stop the collapse. Same test file, 7/7 total. (g) `BaseDigitFormInput.semanticsIdentifier` (+ forwarded by `DigitTextFormInput`) — applied to the **input only**, not the field block. A text input renders its helpText/charCount/error rows as siblings of the box inside its own Column, so the field-level id gets a rect twice the box's height whose centre lands on the seam BELOW the box: run -1432 tapped `nameOfIndividual` at (720,1015) inside bounds `[98,861][1342,1169]`, focused nothing, fired 50 backspaces into the void, and the follow-up `hideKeyboard` BACK popped the page. `container: true` for the same reason as (f). Locked in by `form_input_identifier_test.dart` (3/3), one test of which reproduces the miss and then proves the `_input` id focuses. |
| `06-flow-builder-button-id.patch` | `packages/digit_flow_builder` (stacks ON TOP of the 01 content, which is committed on smc-mc-base-ledger as 48f8074e9) | Crash fix for run -0033's red screen: popup footers (`action_popup_widget`/`select_button`/`signature dialog`) do `FlowWidgetFactory.build(...) as DigitButton`, and 01's outer `Semantics` wrap broke that cast the first time an actionPopup opened ("type 'Semantics' is not a subtype of type 'DigitButton'"). `FlowWidgetFactory.build` now skips the outer wrap for `format == 'button'`; `ButtonWidget` passes the same id into `DigitButton.semanticsIdentifier` instead (needs patch 05's (c)). Ids and selectors are unchanged. |
| `07-forms-engine-live-ids.patch` | `packages/digit_forms_engine` (supersedes patch 02, whose `BaseReactiveFieldWrapper` edit is committed but DEAD CODE — the class has no callers on this branch, proven by run -0108's id-less form page) | (a) `Semantics(identifier: formControlName)` at the LIVE per-field dispatch point (`JsonFormBuilder.build`) — every FORM field id, all formats. (b) `semanticsIdentifier: 'form_action'` on both `forms_render.dart` footer `DigitButton`s (needs patch 05's (c)) — every FORM page's primary button gets one stable id, because each page's label is campaign-localized and page-specific ("Save Location" on Beneficiary Location, run -0108). (c) `radio_builder.dart` passes `semanticsIdentifierPrefix: formControlName` into `RadioList` (needs patch 05's (e)), giving `consentToParticipate_TRUE`, `ec1_NO`, … — scoping by form control name is what keeps ec1..ec5 apart, since all five share the YES/NO codes. (d) `checkbox_builder.dart` passes `semanticsIdentifier: '<formControlName>_checkbox'` into `DigitCheckbox` (needs patch 05's (f)) — the `_checkbox` suffix is deliberate: the bare form control name is already on the enclosing field node, and a duplicate would make the driver hit the non-tappable label block. (e) `string_builder.dart` + `number_builder.dart` pass `semanticsIdentifier: '<formControlName>_input'` into `DigitTextFormInput` (needs patch 05's (g)) — same reasoning, for the input box. `text_area_builder.dart` still needs the same treatment when a textArea field is first automated. |

## Apply (from the repo root)

```
git apply qa/testkit/patches/01-flow-builder.patch
git apply qa/testkit/patches/02-forms-engine.patch
git apply qa/testkit/patches/03-login.patch
git apply qa/testkit/patches/04-boundary.patch
```

Then rebuild the APK — the ids only exist in builds made after applying.

### Patch 05 targets the VENDORED pub package (tracked in-repo)

`digit_ui_components` is pub-hosted, so it can't be patched in place. The exact
locked version (0.3.0+3) is vendored at `packages/digit_ui_components` —
committed on this branch as d9a9445bb (2026-09-02) — and resolved by path via
the app's `pubspec_overrides.yaml` (that entry is NOT melos-managed; re-add it
if `melos bootstrap` regenerates the file):

```yaml
  digit_ui_components:
    path: ../../packages/digit_ui_components
```

Apply `05-ui-components-option-ids.patch` like the others (`git apply` from the
repo root; on Windows with core.autocrlf=true add `--ignore-whitespace` — the
EOL normalization otherwise fails the context match), then `flutter pub get`
in the app (lock flips digit_ui_components to `source: path`) and rebuild the
APK. Apply `06-flow-builder-button-id.patch` together with 05 — 06's
ButtonWidget references `DigitButton.semanticsIdentifier` from 05(c).

For flow_builder's own package-level analysis/tests to see the vendored
DigitButton, its gitignored `pubspec_overrides.yaml` also needs (manual,
re-add after melos bootstrap; the APK build itself doesn't need it — the
app's override wins for the whole build graph):

```yaml
  digit_ui_components:
    path: ../digit_ui_components
```

Verify: in `packages/digit_ui_components`,
`flutter test test/widgets/atoms/dropdown_option_identifier_test.dart` (2/2),
`flutter test test/widgets/atoms/digit_button_identifier_test.dart` (3/3) and
`flutter test test/widgets/atoms/radio_option_identifier_test.dart` (7/7 —
radios + checkbox) and
`flutter test test/widgets/atoms/form_input_identifier_test.dart` (3/3).
The package's own test files fail AT BASELINE — `flutter test
test/widgets/atoms/` is **+52 / −32** with patch 05's lib changes stashed and
**+62 / −32** with them applied (measured 2026-09-03, same 32 failures either
way; the pass count rising by exactly the 10 added tests is what proves the
shared `BaseDigitFormInput` edit broke nothing). Prove any new red is yours the same way: `git stash push -- <the lib
file>`, re-run, compare counts, `git stash pop`.

Before adding a selector for any new field type, read
`qa/testkit/field-selector-map.md` — it maps each config `type`/`format` onto
the widget it builds and the accessibility shape that widget actually exposes,
so you can pick the selector from the code instead of from a failed run.

## Revert

```
git checkout -- packages/digit_flow_builder/lib/widgets/flow_widget_interface.dart
git checkout -- packages/digit_forms_engine/lib/widgets/base_reactive_field_wrapper.dart
git checkout -- apps/health_campaign_field_worker_app/lib/pages/login.dart
git checkout -- apps/health_campaign_field_worker_app/lib/pages/boundary_selection.dart
rm packages/digit_flow_builder/lib/utils/semantics_identifier.dart
rm packages/digit_flow_builder/test/semantics_identifier_test.dart
```

Patch 05:

```
git checkout -- packages/digit_ui_components/lib/widgets/atoms/digit_base_form_input.dart
git checkout -- packages/digit_ui_components/lib/widgets/atoms/digit_button.dart
git checkout -- packages/digit_ui_components/lib/widgets/atoms/digit_checkbox.dart
git checkout -- packages/digit_ui_components/lib/widgets/atoms/digit_text_form_input.dart
git checkout -- packages/digit_ui_components/lib/widgets/atoms/digit_dob_picker.dart
git checkout -- packages/digit_ui_components/lib/widgets/atoms/digit_dropdown_input.dart
git checkout -- packages/digit_ui_components/lib/widgets/atoms/digit_multiselect_dropdown.dart
git checkout -- packages/digit_ui_components/lib/widgets/atoms/digit_radio_list.dart
rm packages/digit_ui_components/test/widgets/atoms/digit_button_identifier_test.dart
rm packages/digit_ui_components/test/widgets/atoms/dropdown_option_identifier_test.dart
rm packages/digit_ui_components/test/widgets/atoms/radio_option_identifier_test.dart
rm packages/digit_ui_components/test/widgets/atoms/form_input_identifier_test.dart
```

Patch 06:

```
git checkout -- packages/digit_flow_builder/lib/widgets/flow_widget_interface.dart
git checkout -- packages/digit_flow_builder/lib/widgets/implementations/button_widget.dart
```

Patch 07 (also add the vendored digit_ui_components override to
`packages/digit_forms_engine/pubspec_overrides.yaml` for package-level
analysis, same as flow_builder's — gitignored, manual, re-add after melos
bootstrap):

```
git checkout -- packages/digit_forms_engine/lib/pages/forms_render.dart
git checkout -- packages/digit_forms_engine/lib/widgets/checkbox_builder.dart
git checkout -- packages/digit_forms_engine/lib/widgets/json_form_builder.dart
git checkout -- packages/digit_forms_engine/lib/widgets/number_builder.dart
git checkout -- packages/digit_forms_engine/lib/widgets/radio_builder.dart
git checkout -- packages/digit_forms_engine/lib/widgets/string_builder.dart
```

Note: the app's `pubspec.lock` flips digit_ui_components to `source: path`
after `flutter pub get` against the override — that lock change is part of the
vendoring (commit it together with the vendored package, not with unrelated
work).

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
