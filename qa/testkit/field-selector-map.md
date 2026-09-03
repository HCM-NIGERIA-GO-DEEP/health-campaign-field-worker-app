# How to pick a selector for a config-driven field

Read this **before** writing a flow step for a FORM page, instead of running the
suite to find out. It maps what the campaign config declares onto what actually
lands in the Android accessibility tree, which is the only thing Maestro can see.

The chain is always:

```
REGISTRATION.json  properties[].type + .format
   -> digit_forms_engine/lib/widgets/json_form_builder.dart  _buildByType()
      -> a JsonSchema*Builder
         -> a digit_ui_components widget
            -> accessibility nodes  <- Maestro selects here
```

`JsonFormBuilder.build` wraps **every** field in
`Semantics(identifier: formControlName)`. That id therefore lands on the field's
**label block**, not on the control. For simple inputs the two coincide; for
composite controls (radio, checkbox) they do not, and that distinction is what
broke runs -1214 and -1315.

## The rule that matters

> A field-level id (`fieldName`) is only tappable when the field IS one control.
> If the control is a box/circle/chip next to a label, the label block absorbs
> the id **and the label text**, leaving the control anonymous — you need an id
> on the control itself.

## Field map

| config `type`/`format` | builder | widget | Accessibility shape | Maestro recipe | Evidence |
|---|---|---|---|---|---|
| `string`/`text`, and the default branch | `JsonSchemaStringBuilder` | `DigitTextFormInput` | one `EditText`, `id=fieldName`, typeable (`isEditable` defaults true in `BaseDigitFormInput`, never overridden) | `tapOn id` → `eraseText` → `inputText` → `hideKeyboard` is safe | code-read 2026-09-03 |
| `integer`/`numeric` | `JsonSchemaIntegerBuilder` | `DigitNumericFormInput` | **read-only stepper.** `id=fieldName` on a NON-clickable container whose `text` is the value; two bare clickable nodes with `accessibilityText` `-` and `+`. `editable` defaults **false** and the builder never passes it | `repeat while notVisible {id: fieldName, text: N}` → `tapOn text: "\\+"`, then `assertVisible {id, text}`. **Never** `inputText`, and **never** `hideKeyboard` after it | device run -1315 + code |
| `string`/`radio`, `boolean`/`radio` | `JsonSchemaRadioBuilder` | `RadioList` | label + all option labels merge into ONE non-clickable block; each circle is a bare clickable node | `tapOn id: <fieldName>_<enumCode>` (needs patch 05(e)) | device run -1214 + tests |
| `boolean`/`checkbox` | `JsonSchemaCheckboxBuilder` | `DigitCheckbox` | box and label are SIBLINGS; field id lands on a block spanning both whose centre is on the text | `tapOn id: <fieldName>_checkbox` (needs patch 05(f)) | semantics probe 2026-09-03 + tests |
| `string`/`select` | `JsonSchemaSelectionBuilder` | `SelectionCard` | each option chip is a SINGLE node carrying **both** the label and the tap action | `tapOn text: "<localized option label>"` — no id needed, and do **not** tap the field id first | semantics probe 2026-09-03 |
| `string`/`dropdown` | `JsonSchemaDropdownBuilder` | `DigitDropdown` | closed field, then overlay rows with `id=option_<code>` | tap the field, then `tapOn {id: "option_.*", text: value}` | device run -1654 |
| `string`/`dob` | `JsonSchemaDOBBuilder` | `DigitDobPicker` | one card = one form field; inner inputs carry `dob_date` / `dob_years` / `dob_months` | type into `dob_years` / `dob_months` (real text inputs — no calendar dialog needed) | code-read; **ids unverified on device** |
| `string`/`locality`, any `readOnly: true` | `JsonSchemaStringBuilder` | `DigitTextFormInput` (readOnly) | `id=fieldName`, value in `text`, not typeable | read/assert only; auto-filled | device run -1315 (`dateOfRegistration`) |
| `string`/`latLng` | `JsonSchemaLatLngBuilder` | custom | **no semantics at all** | never select it; advance with `form_action` | device run -0108 |
| `dynamic`/`custom` | app `components` map | app widget | unknown per component | treat as unverified; make the tap `optional: true` and assert something else | `resourceCard`, `healthFacility` still unverified |
| `hidden: true` | not built (early return) | — | absent from the tree | never reference it | code-read |

## Page navigation

- Every FORM page footer is `id: form_action`, whatever its label. Page labels are
  campaign-localized and page-specific ("Save Location", "Save Household
  Details", "Submit") — never select the footer by text.
- **Always gate a page on a control id from THAT page** before acting. A wait
  that passes does not prove you are where you think you are: in run -1315 a
  `form_action` tap resolved `accessibilityText=Submit` (the consent page) while
  the screenshot showed "Save Household Details".
- Config decides the order. Read `flows[].pages[]` sorted by `order`, not by
  array position, and check `conditionalNavigateTo` for branches.

## Two traps that cost whole runs

1. **`hideKeyboard` is a BACK press on Android.** It is only safe directly after
   an `inputText` that landed in a *real, editable* text field — then the open
   IME swallows the BACK. After a read-only widget (the numeric stepper) no IME
   is open and the BACK pops the page.
2. **Ids exist one relayout before labels localize.** A config screen's ids are
   live while its text is still `RAW_KEY`, and the layout shifts when the strings
   resolve. Gate on a *translated* string first (raw keys are
   `ALL_CAPS_UNDERSCORE`, so they cannot match a human-readable regex).

## When a step still fails

Dump **every** node from the failure hierarchy, including the ones with no text
and no id — that is where anonymous controls hide:

```powershell
# reports\maestro-<stamp>\.maestro\tests\<ts>\<flow>\screen-hierarchy\*.json
```

and read the `Tapping on element:` lines in that flow's `maestro.log` — they
print the resolved node's id, label AND bounds, which is how both the stale-bounds
and wrong-page failures were caught.
