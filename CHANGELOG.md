# Changelog

## 2.2.111 — 2026-09-04

_Security release. The five VAPT mitigations were already present; this release makes each one selectable, verifiable and survivable in the field, and fixes three defects in them. Full detail in `SECURITY_RELEASE_NOTES.md`; the pinning design and its trade-offs in `SSL_PINNING.md`._

**SSL pinning (`lib/security/network/ssl_pinning.dart`, `assets/certificates/tls_cert.crt`)**

- The pinned anchor moved from the server leaf to its issuing CA (`Sectigo Public Server Authentication CA DV R36`, expires 21 Mar 2036). Pinning fails closed, and a leaf expires within months, so every certificate renewal would have taken every installed build unable to reach the API at all — field devices do not update on demand, making that an availability incident rather than a security one. Routine leaf renewal now needs no app change; only a change of CA does. The cost is that trust widened from one certificate to one CA, which is stated rather than glossed: hostname verification still applies to the leaf, and abusing the pinned DV CA would require control of `campaigns.afro.who.int`.
- The certificate that shipped previously had **expired on 17 Apr 2026** and was issued for `kebbi-hcm-uat.digit.org`, a host unrelated to the configured `BASE_URL`. Pinning had no test, which is how it went unnoticed.
- A missing or malformed certificate no longer throws during startup. `main.dart` awaits `enableSSLPinning()` before the UI exists and `background_service.dart` does the same in the sync isolate, so an unparseable asset previously failed the app to launch and killed sync silently. The failure is now recorded on `AppSecurity.sslPinningFailure` and a client that refuses every request is returned — `badCertificateCallback` blocks TLS and `connectionFactory` fails before a socket opens, which also blocks cleartext. Deliberately *not* implemented: falling back to the default client, which would silently restore system and user CA trust and turn a packaging mistake into an undetected loss of pinning.
- Added `tools/security/rotate_pinned_cert.sh`, which fetches the live chain, resolves the requested anchor by walking issuer links rather than trusting chain order, and refuses to write an anchor that does not validate the live server using the app's own semantics (`-partial_chain`, system store excluded). `--add` produces a bundle trusting both the outgoing and incoming CA for a CA migration, since a pin cannot be pushed to an installed app and the release must therefore precede the server switch.

**Selectable mitigations (`lib/security/`)**

- `AppSecurity` exposed only a `low`/`medium`/`high` dial. Each mitigation is now selectable individually via `AppSecurityFeature`, with every device-integrity layer and SSL pinning gated on its own feature. Level presets preserve prior behaviour exactly.
- `AppSecurityFeature.isRuntimeEnforced` separates what Dart can enforce from what the build decides. Code obfuscation, component export and platform hardening are properties of the APK, so selecting one is a declaration of intent that `verifyBuildTimeMitigations()` checks against the shipped artifact via a new `auditBuildConfiguration` channel method — reporting `minifyEnabled` (through an injected `IS_MINIFIED` `buildConfigField`, since R8 leaves no queryable runtime flag), `debuggable`, `allowBackup`, cleartext policy and unguarded exported components. Offering runtime toggles that silently do nothing would have been worse than not offering them.
- Security code moved out of the `lib/` root, the `lib/utils/` grab bag and `lib/data/remote_client.dart` into a single `lib/security/` module: two files carrying eight responsibilities became fourteen with one each. Detection no longer decides how to respond, and no longer reads the environment.

**Device integrity defects fixed (`lib/security/integrity/`)**

- A plugin failure no longer terminates the app. Any exception from the root-detection library became an `unknown` threat, which failed the pass and reached `exit(0)` in production — so a `MissingPluginException` or an unsupported OEM device killed the app, with no log because `debugPrint` is silenced at `high`. Native probes now return `null` for "could not run", which is reported as an unavailable check and never escalated into evidence of tampering.
- Threat response became an injectable policy (`exitApp`, `restrict`, `reportOnly`) instead of a line inside detection. `restrict` is reachable for the first time: the compromised flag is set before any termination, where it previously sat after an unconditional `exit(0)` and could never execute.
- The threat "checksum" mixed in `DateTime.now()`, so it could never be compared with anything despite being labelled for integrity verification. Replaced by a deterministic, order-independent digest of the threat set, documented as a server-side deduplication key and explicitly not a proof.
- Periodic re-checks use a cancellable timer rather than an unbreakable `while (true)` loop, and no longer block startup. `envConfig.variables` reads are guarded, since it throws before `initialize()`.
- Removed dead code: an unused root-detection BLoC and wrapper (210 lines, every line commented out) and a stale generated file.

**Code obfuscation (`android/app/proguard-rules.pro`)**

- `proguard-rules.pro` carried both `-keep,allowobfuscation class com.digit.hcm.SecurityHelper` and a blanket `-keep class com.digit.hcm.** { *; }` retained from an earlier merge. The blanket rule is more permissive and wins, so `Lcom/digit/hcm/SecurityHelper;` shipped **readable in the DEX**, defeating the narrower rule and contradicting the warning in that same file against blanket keeps. Removed and confirmed against a rebuilt release APK: `SecurityHelper` is renamed while `MainActivity`, `LauncherActivity` and `LocationService` keep the names the manifest resolves by.

**Security test tooling (`tools/security/`)**

- Coverage went from 9 checks to 31, with a new `test_ssl_pinning.sh` for the mitigation that had none. Outcomes now include SKIPPED and INCONCLUSIVE, and a mitigation that could not be verified reports "Not verified" rather than passing — unverified is not the same as safe, and the previous aggregation could only say passed or failed.
- Several checks were reporting VULNERABLE on conditions they could not observe: a commented-out XML attribute read as configuration, an `aapt2` attribute id matched as a value, a Dart string literal mistaken for a retained symbol, and a chain check that passed against any CA because it consulted the system trust store. Each now has a negative control.
- `--dart-define=SECURITY_TEST_MODE=true` builds an APK whose detection is observable from outside — log suppression off and response mode `reportOnly` — because a shipped build silences `debugPrint` and calls `exit(0)`, which is correct for production and made the root-detection tests report VULNERABLE while detection was in fact firing. It defaults to false and must never be set for a build that ships.

**Known gaps carried into this release**

- The release build type still uses `signingConfig signingConfigs.debug` with a TODO. A conditional release config driven by `key.properties` exists but is not referenced. This must be resolved before publishing.
- The Kotlin and Gradle changes were not compiled and the Dart tests were not executed, because `flutter pub get` fails on a pre-existing `bloc_test` / path-pinned `dart_mappable_builder` conflict. Run `melos bootstrap` first.
- `DioClient.disableSSLPinning()` is never called and remains a live way to silently unpin the app.
- Repackaging detection stays inert until an expected signing certificate is supplied via `AppSecurity.configure(expectedAppSignature:)`.
- A pin cannot be pushed to an installed app, and an expired anchor cannot be recovered server-side — BoringSSL rejects an expired trust anchor, confirmed with a purpose-built expired CA against a local TLS server. Prevention is the control.

## 2.2.110 — 2026-09-01

_(includes 2.2.107 and 2.2.109; 2.2.108 was never cut — the version bump went straight from `2.2.107+107` to `2.2.109+109` in a single commit)_

**Bulk entity creation (`CrudService`, `LocalRepository`, `CrudExecutor`)**

- `CrudService.createEntities` no longer creates entities one-by-one. It now groups them by runtime type and, for any group with more than one entity whose repository is a `LocalRepository`, routes the group through a new `LocalRepository.bulkCreateEntities` (a `List<EntityModel>`-accepting wrapper that casts to `List<D>` and delegates to the existing `bulkCreate`), falling back to individual `create` calls when `bulkCreate` throws `UnimplementedError`. Per-entity failures are also no longer fatal to the rest of the batch: each failure is collected and a single aggregate `Exception` is thrown after every entity has been attempted, where previously the first failure aborted the loop.
- `CrudExecutor` (the `CREATE_EVENT` action) was switched from dispatching `CrudEventCreate` on `CrudBloc` — fire-and-forget — to `await`ing `CrudBlocSingleton().crudService.createEntities(...)` directly, so persistence completes before later actions in the same chain (e.g. `NAVIGATION`) tear the screen down. Two consequences of bypassing the bloc: no `CrudState.loading`/`persisted`/`error` is emitted for this path any more (nothing in the tree listens for them on the create path, and the analytics `*_complete` events are emitted by `FlowCrudBloc`, not `CrudBloc`, so neither is lost), and the aggregate exception from `createEntities` is caught and only `debugPrint`ed by `ActionExecutorRegistry.execute`, which then returns the original context data and lets the remaining actions run. A failed create is therefore still silent to the user — the behavior this change actually buys is ordering, not error surfacing.
- As shipped in 2.2.107 the bulk path wrote no oplog entries. `LocalRepository.create` queues an `OpLogEntry` via `createOplogEntry`, but `bulkCreate` deliberately does not (it exists for sync-*down*, where rows already exist on the server), and the new wrapper simply delegated to it. Any locally created batch of two or more same-type entities — the multi-task `DELIVERED` submission this feature was written for — was written to the local DB and never queued for sync-up, so it would never reach the server. 2.2.109 fixes this: `bulkCreateEntities` now takes a `createOpLog` flag (default `true`) and writes one `create` oplog entry per entity after the batch insert. The commit message ("enhance `bulkCreateEntities` to log operations") reads as instrumentation; it is a sync data-loss fix for a regression this release introduced three commits earlier, and any build cut at 2.2.107 or 2.2.108 carries it.
- Two smaller asymmetries remain between the bulk and single-entity paths: `bulkCreateEntities` is not wrapped in `retryLocalCallOperation` the way each repository's `create` is, and its oplog writes happen after — not inside — the Drift batch, so a crash between the two leaves persisted records with no sync-up entry.

**RI age eligibility (`checkRIEligibility`, new `ri_age_eligibility.dart`)**

- The RI upper age bound no longer comes from `projectType.validMaxAge ?? 59`. It is now a hard 59 months, overridable only by an optional 4th argument to `fn:checkRIEligibility(dob, tasks, cycle, maxAgeMonths)`, resolved through a new import-free helper file (`resolveRiMaxAgeMonths`, `isRiAgeEligible`, `riDefaultMaxAgeMonths = 59`) that tolerates ints, numeric strings, leftover `{{ }}` templating and surrounding quotes, and falls back to 59 for anything absent, unparseable or non-positive.
- The rationale given is that `validMaxAge` encodes SMC aged-out continuation policy and can exceed 59 (Plateau SMC-RI carried 64, exposing RI to 60–64-month-olds). Worth noting the change cuts both ways: for any campaign whose `validMaxAge` is *below* 59 the ceiling has now been raised to 59 rather than lowered, since the campaign value is no longer consulted at all. No config in this repo passes the 4th argument — every `fn:checkRIEligibility` call in `registration_flows.dart` uses 3 args — so until MDMS configs are updated, every campaign gets exactly 0–59 inclusive.
- `resolveRiMaxAgeMonths` does not clamp its result at 59, so a config that passes a larger 4th argument can still widen RI eligibility past 59; what the change removes is the *implicit* widening via the SMC project type.
- The new file's doc comment states it is kept import-free "so unit tests compile"; no tests were added, and `packages/digit_flow_builder` has no `test/` directory.

**Stock metrics (`stock_calculation_utils.dart`)**

- `_processDistributorStock` now returns immediately when the record's status is `REJECTED`, so rejected transactions are excluded from a distributor's stock figures entirely. The dispatched-sender path (`_categorizeDispatchedStock`) already had this guard; the distributor path did not.
- The practical effect is mostly on rejected *returns*: a distributor's `RETURNED` record that the warehouse rejected previously still added to `stockReturned` (plus wastage/partial-used) and so was deducted from stock in hand, leaving the distributor's balance short of stock they never handed over. It now stays in hand until the return is accepted.
- The guard was not extended to the non-distributor receiver path: `_categorizeReceivedStock` takes no `status` argument at all, so a `REJECTED` record still counts as received stock for facility/warehouse users. `status` here is read from the record's `additionalFields` (`_getAdditionalFieldValue(stock, 'status')`), not a top-level model field, so records that carry no `status` field resolve to `''` and are unaffected either way.

## 2.2.106 — 2026-08-20

**Eligibility / cycle logic in `function_registry.dart`**

- The lastModifiedTime-based cycle-derivation logic inside `checkEligibilityForAgeAndSideEffect` was extracted into a standalone `getTaskCycleIndex(task, projectType)` helper, with no change to the derivation logic itself.
- Task iteration in `checkEligibilityForAgeAndSideEffect` was changed back from `tasks.reversed.toList()` (newest-first, introduced in 2.2.105) to plain `tasks` (oldest-first), reversing that prior release's iteration-order change.
- The early-eligible path — where an out-of-cycle, out-of-age task with `administrationSuccess` status made the function return `true` immediately — was removed from the main disqualification loop and moved into a new second loop that runs afterward and only considers tasks whose `additionalFields` records `flow: "smcDone"`. For tasks without that flow marker, an out-of-cycle, out-of-age `administrationSuccess` status no longer makes the beneficiary eligible.

## 2.2.105 — 2026-08-18

_(includes 2.2.102, 2.2.103, 2.2.104)_

**Analytics integration (new feature, ships disabled by default)**

- A new `digit_analytics` package was created, providing an Isar-backed event queue (`AnalyticsQueueManager`, modeled on the existing sync oplog but kept separate from it) and an `AnalyticsService.instance.logEvent(...)` API that is a no-op unless analytics is enabled.
- `digit_firebase_services` gained `initializeAnalytics`/`logFirebaseAnalyticsEvent` wrappers, splitting the previous single `initialize()` call into separate core/Crashlytics/Analytics steps.
- The app was wired up to log `login`/`logout` events, per-screen `screen_view` events (including a fix so `digit_flow_builder`'s dynamic flow pages — which all otherwise share one route name — log distinguishable per-step screen names), and completion events for every persisted entity type (registrations still group into one `registration_complete` event; other entity types now each fire their own auto-derived `<entity>_complete` event). A new `AnalyticsSyncService.flushPendingEvents()` pushes the local queue to Firebase Analytics on reconnect and during regular sync-up.
- A debug-only analytics event viewer/management page was added, reachable from Home and hidden in production release builds.
- One commit in this sequence, described only as adding the event viewer, also silently flipped the `enableAnalytics` default from `false` to `true` in both `constants.dart` and `background_service.dart` — with no mention of that change in its commit message. Two follow-up commits explicitly titled "disable analytics by default" flipped both fallbacks back to `false`, so by 2.2.105 analytics remains off unless the remote `firebaseConfig.enableAnalytics` MDMS config explicitly turns it on — the same behavior as before this feature was built, net of the accidental one-commit regression in between.

**Campaign ID configuration**

- The SMC-RI and ORS-Zinc campaign IDs in `ProjectBloc` are no longer hardcoded strings; they now read from new `SMC_RI_CAMPAIGN_ID`/`ORS_ZINC_CAMPAIGN_ID` environment variables, falling back to the event's own `referenceID` when the environment value is empty.

**Eligibility / cycle logic in `function_registry.dart`**

- `checkEligibilityForAgeAndSideEffect` (SMC) no longer looks up `cycleIndex` from the task's `additionalFields`; it now always derives the task's cycle from `lastModifiedTime` against the project's cycle date ranges. This change was made only in this function — `checkRIEligibility` still uses the fields-based lookup, so SMC and RI eligibility now resolve their task's cycle differently.
- A block that normalized each task to a `Map` before use was removed. It was confirmed dead code: the tasks list already arrives pre-normalized as `List<Map<String, dynamic>>`, so the removed branches could never run. This is a pure cleanup with no behavior change, matching its commit message.
- A change that made an out-of-cycle, out-of-age task with an `administrationSuccess` status immediately count as eligible was landed, then fully reverted the same day. The revert restores the tree to its pre-change state byte-for-byte — while it was live, the change was materially narrower than its commit message ("enhance... check") suggested: it required *both* a past-cycle administration-success record *and* a separate current-cycle administration-success record before returning eligible, rather than either being sufficient.
- The final change in this release reverses the order in which a beneficiary's tasks are iterated (from oldest-first to newest-first) inside `checkEligibilityForAgeAndSideEffect`. Because the loop returns as soon as it hits a task matching one of several disqualifying or qualifying conditions, this is a real behavioral change, not a stylistic reorder: for a beneficiary whose task history contains multiple tasks that would independently trigger different outcomes (for example, a `beneficiaryDied` task from one cycle alongside an `administrationSuccess` task from another), which status wins now depends on iteration order, and that order was just flipped.

**Stock / list view**

- Stock and stock-reconciliation records shown outside an active delivery flow (e.g. from the Stock Reports screen on Home) are now filtered to the active cycle's date window, resolved via the currently selected project type rather than the delivery-flow singleton that isn't populated in that context. "Stock Received" rows are additionally required to have an `ACCEPTED` status to be counted.
- A logging call that printed every CRUD bloc state transition — including full search-result graphs on each pagination page load, which could take upward of ten seconds — was silenced for CRUD blocs, since it was starving the loading indicator from ever painting.
- Top-level list-view bodies in the dynamic flow layout renderer were switched from an eagerly built `Column` of every loaded item to a lazily built `SliverList`, giving genuine list virtualization instead of rendering the whole loaded set up front.
- A minimum 350ms display duration was added for the loading indicator, and the modal loader is now driven directly by a value listener rather than through `build()`, because a fast local-DB pagination fetch could otherwise show and hide the loader within the same frame and never paint it.

**JsonFormBuilder**

- Dynamically shown/hidden form fields in `JsonFormBuilder` are now keyed by field name (`ValueKey(subName)`). Previously, with no key, Flutter's positional list reconciliation could let one field inherit another field's live widget state — including its form control — whenever a visibility change shifted list positions. This is a real state-reuse bug fix, not merely, as the commit message put it, "improved widget identification."

## 2.2.101 — 2026-08-05

_(includes 2.2.99, 2.2.100)_

**Eligibility / cycle logic in `function_registry.dart`**

- A new age-only eligibility gate, `_isEligibleAge(projectType, totalAgeMonths)`, replaced the dose-criteria-based `_isEligibleFromDoseCriteria(currentCycle, totalAgeMonths, individual)` as the age check inside `checkEligibilityForAgeAndSideEffect` (3 call sites), `isORSEligible`, `vasWithinTheAge`, and `orsWithinTheAge`. This is a real simplification, not just a new check: the new function only compares `totalAgeMonths` against `projectType.validMinAge`/`validMaxAge`, dropping the per-cycle dose-criteria condition strings and weight/height clauses `_isEligibleFromDoseCriteria` supported. `_isEligibleFromDoseCriteria` is now dead code — still defined, no longer called.
- That new function initially used strict bounds (`totalAgeMonths > minAge && totalAgeMonths < maxAge`), wrongly excluding a beneficiary exactly at the min or max age boundary. A same-day follow-up changed both comparisons to inclusive (`>=`/`<=`).
- `checkRIEligibility` was reworked: it no longer returns false outright for a task with status `beneficiaryDied`/`ineligible` (regardless of cycle) or, for the current cycle, `beneficiaryMigrated`/`beneficiaryAbsent`/`beneficiaryRefused` — all of that status-based logic was removed. It now only checks whether the beneficiary has *any* RI task recorded in the current running cycle (via `cycleIndex`, falling back to deriving the cycle from the task's `lastModifiedTime` against the project's cycle dates when `cycleIndex` is missing); if so, ineligible, regardless of that task's status. Net effect: a `beneficiaryDied` task from a past cycle no longer disqualifies a beneficiary going forward, which the old code did unconditionally.
- The RI full-immunization check got the same `lastModifiedTime`-derived cycle fallback, but also flips two defaults: with no active cycle (`currentRunningCycle == null || .id == 0`) it now returns `false` where it used to return `true`, and when a task's cycle can't be determined at all it now falls through to `false` instead of `true`. Both changes make the function default to "not fully immunized" instead of "fully immunized" when cycle data is ambiguous — a real behavioral inversion the "refine checks" commit message undersells.

**Stock**

- `StockBalanceCard` cached computed stock balances via `StockBalanceCache.instance.setCache(...)` *before* applying the server-report stock-consumption deduction to `_stockBalances`, so the cache permanently held pre-deduction figures while the card displayed post-deduction ones. The fix moves the `setCache` call after the deduction, caching the final `_stockBalances` — a real cache/UI mismatch bug fix, not a vague "caching logic update."
- The stock-downsync cursor's "+1 ms past the latest downloaded record" fix (to avoid re-fetching that same record next sync) was applied independently in two separate cursor-writing code paths — `StockDownSyncBloc` and `ProjectBloc`'s own inline stock-download routine — the same off-by-one bug present in, and fixed in, both places rather than one fix duplicated.
- `getFacilityName` was changed to accept a second `deliveryTeamName` argument and return it instead of the raw `facilityId` for non-facility (STAFF/delivery-team) senders. No call site — not `INVENTORY.json` nor `manage_stock.dart` — was updated to pass that second argument, so it always defaults to `""`. The practical effect is that non-facility sender names now render blank instead of the previously-shown raw id/QR string, not "including the delivery team name" as the message implies.

**Summary report**

- The summary report's household-download step in `ProjectBloc` now returns immediately for any role other than distributor/CDD, and keys off `userObject.uuid` for the facility id instead of falling back through `currentFacilities`. This fix was committed separately but byte-identically on both `feat/smc-mc-borno` and `feat/smc-mc-plateau-ri` (same author, same timestamp) — a genuine duplicate landing that the merge reconciles into one.

## 2.2.98 — 2026-07-28

- The two commits that make this change look like duplicates going by their messages, but the second one is fixing a wrong value the first one shipped — it isn't a no-op.
- A `'RI': 'riQ1'` symptom-to-checklist key mapping was added so that `computeReferralButtonLabel` resolves correctly for RI referrals instead of falling through unmapped.

## 2.2.97 — 2026-07-28

_(includes 2.2.96)_

- The inverted eligibility check introduced in 2.2.95 was reverted, restoring `eachCycleData.isEmpty` in `function_registry.dart`. The underlying bug was a flipped boolean, not the vaguer "logic correction" the commit message implied.
- Age-vs-cycle validation was reworked: the `isFirstCycle`/`eachCycleData` tracking added in 2.2.93 was removed entirely, replaced with logic that short-circuits to eligible when a task's cycle doesn't match the current cycle and the beneficiary is out-of-age but has a prior successful administration on record. A fallback was also added that derives a task's cycle index from its `lastModifiedTime` against the project's cycle dates whenever the `cycleIndex` field is missing.
- The same cycle-derivation-from-`lastModifiedTime` fallback and cycle filter were applied to the VAS and ORS eligibility checks, bringing them in line with the SMC logic above.
- Stock-entry dates across three stock widgets now fall back to `lastModifiedTime` instead of `createdTime`, and stock shown in `stock_reconciliation_card.dart` is now filtered to the current cycle's date window (it wasn't filtered before). The same commit also removes a 144-line dead method, `_createStockBalanceUserActions`, from `ProjectBloc` — unrelated cleanup that rode along with the date fix.
- The stock-downsync cursor now advances to the latest `auditDetails.lastModifiedTime` among downloaded records (server clock) and never regresses below its previously stored value — a further revision of the cursor behavior changed in 2.2.95.

## 2.2.95 — 2026-07-21

_(includes 2.2.94)_

- Fixed a bug where a second CDD user sharing a device could have their stock silently withheld: the stock-downsync cursor moved from a single device-wide `Downsync` table row to a `SharedPreferences` key scoped per project, user, and cycle.
- The summary report no longer re-downloads when local household data already exists for the current cycle, checked via `createdBy`/`createdTime` against the cycle's date bounds.
- The unused `facilityId` parameter was removed from `ServerSummaryReportService`, `ServerSummaryReportStorage`, and `home.dart` — reports are no longer facility-scoped.
- **This release introduced a bug**: the ineligible/administer-success task filter in `function_registry.dart` dropped its early `return false` for `TaskStatus.ineligible` and flipped the eligibility check to `eachCycleData.isNotEmpty`. That inversion was wrong and was reverted the following release, 2.2.97.
- Cycle-index matching was added to the ORS delivery status check, matching the equivalent SMC/VAS behavior.
- The default row height in `TableWidget` was raised from 52 to 70. Two commits landed this ("adjust for spacing" then "update default row height"), and together they net out to just that height change — a `+50` padding tweak was added and then removed in between, so the "accommodate additional spacing" framing overstates what actually shipped.

## 2.2.93 — 2026-07-20

_(includes 2.2.88, 2.2.89, 2.2.90)_

**Server Summary Report Service** (new feature, built incrementally across 5 commits)

A new server-backed reconciliation layer was introduced so that summary and stock figures reflect work submitted from *other* devices, not just what's in the local database. This adds a `ServerSummaryReportService` and `ServerSummaryReportStorage` (backed by `SharedPreferences`, keyed by user, project, facility, and cycle) plus a `SummaryReportRemoteRepository` that queries `product/summary/v1/_search` (the path is configurable via `SUMMARY_REPORT_API_PATH`). `ProjectBloc` fetches the server report when a project is selected and syncs it into storage, and `HomePage` initializes the service per context, resolving the facility either from the distributor role or from the "current" project's facility. The service is then used to filter out local tasks, households, and members already reflected in the server report (by comparing `lastModifiedTime` against the server report's timestamp, avoiding double-counting) and to add the server-reported counts — households registered, children treated or registered, stock consumed — on top of local counts in the `StockBalanceCard`, `ProductSelectionCard`, `SummaryReportPage`, and `BeneficiaryProgressBar`. A later commit adds an `allDates()` method so that dates with only server activity and no local activity still show up as rows in the summary report table.

**Cycle-aware eligibility/stock filtering**

- Eligibility checks were reworked to track whether a beneficiary is in their first cycle and how many SMC tasks they've had per cycle, so an under-age beneficiary is only rejected outright on their first cycle. A same-day follow-up commit fixed an inverted condition (`flowType != "smcDone"` should have been `==`) and narrowed the "not enough cycle tasks" rejection so it only applies when the beneficiary is also out-of-age.
- Stock entries in the product selection and stock balance cards are now filtered to the selected cycle's date range before stock-in-hand is computed.
- A `showAttendanceCard` function was registered to gate the attendance card's visibility based on the beneficiary's enrollment and de-enrollment dates relative to the selected date.
- `ProjectBloc`'s `currentCycleStartDate` logic was simplified to derive the date from `project.additionalDetails` cycles first, falling back to the first cycle if none is currently active (it previously read from the secure-store project type first).

## 2.2.87 — 2026-07-07

_(includes 2.2.86)_

- `isDelivered` task-status checks now validate against the active project cycle: the current cycle is resolved from `ProjectType.cycles`, tasks whose `cycleIndex` doesn't match are skipped, and the check returns false if no cycle is currently active. Previously, a task delivered in a past cycle could still satisfy "delivered" for the current one.
- `disableEdit` was extended with the same current-cycle matching, reusing (rather than duplicating) the existing "referral matches current cycle" check, which was moved earlier in the function to make that reuse possible.
- `resolveReferralReasons` now short-circuits to `['RI']` whenever `navigationData['sourceFlow'] == 'RI_CHECKLIST'`, bypassing the normal reason-derivation logic for that flow.
- Address transformer mappings for latitude, longitude, and location accuracy were switched from `address.latLng[0]/[1]` to `__context:latitude/longitude/locationAccuracy`. This also fixed a pre-existing bug the commit message didn't mention: location accuracy had been wrongly mapped to the same value as longitude (`latLng[1]`). A follow-up commit, described as "update address location fields," applies that identical fix to two more transformer blocks — it reads like a new feature but is really the same fix extended to more places.

## 2.2.84 — 2026-07-03

- An `RI` symptom-to-checklist mapping was added for `computeReferralStatus`.

## 2.2.83 — 2026-07-01

_(includes 2.2.79, 2.2.80, 2.2.81, 2.2.82)_

- Downsynced stock entries in `ProjectBloc` were filtered to the beneficiary's current cycle window — and then, in a later commit within this same release, that client-side filtering was removed again (synced stock is now bulk-created unfiltered) in favor of seeding the sync cursor's `lastSyncedTime` from the cycle start date instead. The net effect is that cycle-window handling moved from filtering after sync to seeding the sync's starting point, which is a different mechanism than the "implement current cycle date handling" commit message suggests.
- Summary-report metrics (households, tasks, members, stock) are now filtered to only include records whose `createdTime` falls within the currently selected cycle.
- The hardcoded `getSymptomsReferral` logic was replaced with a shared `resolveReferralReasons` helper that produces a priority-ordered list (ADR, then SICK, then FEVER). The old RI/checklist branch of that logic (zero-dose, partially immunized, unimmunized) was dropped in this rewrite.
- The household head's name and location were added to the referral payload.
- `isNotSingleSession` now defaults to `false` instead of `true` when no register model is supplied — a real behavior flip, not just a configuration default tweak.
- The registered function `individualName` was renamed to `fullName`.
- `AttendanceLogsLocalRepository.create` now checks whether a record already exists and routes to `update` instead of blindly inserting, preventing duplicate or overwritten records.
- Two now-unused task table indexes were dropped.
- A report-table scroll issue was fixed by adding an opt-in `fitToContent` flag that lets `DigitTable` fill a fixed-height box instead of scrolling twice.
- `.gitignore` was updated to cover environment files and their variants.

## 2.2.78 — 2026-06-24

_(includes 2.2.67, 2.2.69–2.2.77 — Kogi jumps from 2.2.61 directly to 2.2.67)_

**VAS / ORS multi-round campaign delivery**

- A full second delivery pathway for ORS was added, mirroring VAS end-to-end: an `orsProjectType` context getter, an `orsDelivery` transformer config, `isORSDelivered`/`isORSEligible`/`orsWithinTheAge`/`getORSProjectCycles` registry functions, and a new `ORSDELIVERY` resource-card registration.
- `vasProjectType` and `orsProjectType` now build their `ProjectTypeModel` dynamically from `ProjectBloc.allProjectTypes`/MDMS data, instead of from a hardcoded object with fixed cycle dates and product-variant IDs.
- `isDelivered`, `isVASDelivered`, and `isSMCFlowDone` were rewritten to accept a **list of tasks** instead of a single status/flow pair — a real change to their signature and behavior, not just the "logic update" the commit message describes. `isSMCFlowDone` now also treats an ineligible task status as done, and separately checks referral records for an `SMCDONE` flag regardless of task status.
- Tasks flagged `REDOSE`, `VASDONE`, or `ORSDONE` are now excluded from delivery evaluation, and a `vasWithinTheAge` check was added to validate age eligibility against the active cycle's dose criteria.
- `ProjectBloc` hardcodes the campaign ID `CMP-2026-06-17-000376` whenever the project type is "ORS-Zinc" — a temporary override rather than the general "campaign ID handling" the message implies.
- ORS dose-criteria condition strings get `.replaceAll('age', 'ageandage')` applied, and the product name is forced to `'ORS-Zinc'`. This is an unusual string-patching workaround rather than a clean fix, and is worth confirming it isn't papering over a parser bug.
- The resource card now picks `vasProjectType` versus the default project type based on whether `sourceFlow == 'VASCHECKLIST'`, and `VASDetails` was renamed to `VASDeliveryDetails` throughout the transformer config.
- Checklist referrals (`CHECKLIST`/`VASCHECKLIST`) now default to `'SICK'` instead of returning null when no answers were given.

**Delivery-team display and stock**

- `getFirstPageParty`/`getSecondPageParty` were reworked so that STAFF-type parties (a scanned delivery-team member) display the captured team member's name instead of `FAC_<id>`, while facility parties get a `FAC_` prefix. New helper functions extract the name from a `"userName||userUuid"` QR string or fall back to context. This landed as a chain of several commits, not the single fix their messages suggest.
- The user QR code payload changed from a bare user UUID to `"userName||userUuid"`, which is what enables the name extraction above.
- The `multiplier` and `calculatePartial` parameters were removed from `StockCalculationUtils` calls in the summary report, product selection card, and stock balance card — these had previously always been passed as the bottle-to-ml multiplier and `true`.
- The transformer config now threads eligibility-checklist answers (`ec1Value` through `ec5Value`) and `deliveryTeamName`/`ageInMonths` (via a new `__ageInMonths:` directive) into task additional fields — this is the actual mechanism behind the commits labeled as "fix checklist data save."

**Search and query performance**

- `MultiTableFilterResolver` gained `buildCrossTableConstraintExpressions`, which converts cross-table filters into SQL `IN (SELECT ...)` subqueries instead of materializing primary-key sets in Dart, and added column projection to avoid fetching full rows.
- `QueryBuilder`'s LIKE clauses now wrap each column with `isNotNull()` so that `NULL OR ...` no longer silently drops rows. The old `contains` operator (a prefix match, index-friendly) was split from a new `matches` operator for substring search, and geo/Haversine counts now go through `selectOnly` so cross-table constraints are no longer dropped from those counts.
- The search bar got a 300ms debounce, and the minimum characters required for ID search was lowered from 12 to 3.

**Login and localization**

- `LoginPage` now waits for `LocalizationBloc.isLocalizationLoadCompleted` and shows a loading spinner before rendering the form, instead of briefly flashing untranslated labels. `triggerLocalization` was also moved into a `Future.microtask`.

**Scanner and QR**

- An `allowManual` flag was added to the scanner builder and route, to allow disabling manual entry per field, along with regex validation for manual QR input and a new `INVALID_QRCODE` error message.

**Infrastructure**

- The launcher icon was updated, a release signing configuration was added, and a downsync trigger was added for the distributor role on boundary selection.

## 2.2.66 — 2026-06-09 *(Kaduna/Jigawa branch)*

- The same `multiplier`/`calculatePartial` handling added for the product selection card in 2.2.65 was applied to the summary report's stock computation too, keeping the two screens consistent.
- `hcm-common` was appended to five localization-trigger module strings in `home.dart` (registration, inventory, stock reconciliation, HF referral, and stock reports flows), so a shared common-module locale bundle loads alongside the module-specific ones.
- `firebase_options.dart` was changed so that **iOS Firebase support was dropped entirely** — it now throws `UnsupportedError` instead of returning configuration. The commit message ("update FirebaseOptions") understates that iOS support was removed, not just updated.

## 2.2.65 — 2026-06-04 *(Kaduna/Jigawa branch)*

- Stock-in-hand math was corrected by applying the bottle-to-ml multiplier in the right order relative to delivery-task quantities, since task quantities are already recorded in ml and were being double-scaled. The commit message ("no multiplier needed") describes this as removing the multiplier, but it's really a reordering fix, not a removal.
- A bottle-to-ml `multiplier` and a new `calculatePartial` flag were added to the product selection card's stock computation, and the validation message's maximum value is now converted back from ml to a bottle count.
- The inline condition-string parsing used for REDOSE dose-criteria matching was replaced with a shared `filterEligibleDoseCriteria` helper that also considers optional weight and height, not just age. The commit message ("eligibility criteria updated") undersells that this adds weight/height support through a new, reusable function.
- Null values are now stripped before writing additional fields in both `FormEntityMapper` and `UpdateExecutor`, and height/weight were wired into the transformer config context.

## 2.2.61 — 2026-06-09

_(includes 2.2.60)_

**RI (Routine Immunization) checklist flow — HDDF-5403**

- An RI eligibility checklist form was added, along with an alert popup that shows numbered guidance points on checklist submission.
- A `riAdministrationConfig` was added to tag RI tasks and referrals with `additionalFields.flow: riDone`, alongside the existing SMC handling.
- Tasks and referrals throughout `function_registry.dart` were split into RI versus SMC using the new `flow` key, and `checkAllRIDoseDelivered` was replaced with a new `hasRIAdministered` function. This is a substantially bigger change than "filter tasks via helper methods" suggests — one commit alone changed +254/-61 lines.
- RI checklist symptoms (zero-dose, partially immunized, unimmunized) are now mapped into referral reasons, alongside the existing SMC mapping.
- RI's minimum valid age was hardcoded to 0 months, decoupling it from the SMC project-type configuration it previously fell back to.
- Two commits together actually **invert** what a function tests for: `riAdministrationConfig`'s task status changed from `ADMINISTERED` to `INELIGIBLE`, paired with renaming `hasRIAdministered` to `hasRIFullyImmunized` and flipping its logic to check for an `INELIGIBLE` status (not an administered one) plus `flow == riDone`.

**Firebase**

- Firebase (`firebase_options.dart`/`firebase_core`) was added, then heavily edited, then fully removed from the `digit_flow_builder` package — the net effect across this range is that the package no longer depends on Firebase at all.
- The app's own `firebase_options.dart` now throws `UnsupportedError` for iOS instead of returning configuration — iOS Firebase support was effectively dropped, not just "refined" as the message suggests.
- `hcm-common` was appended to every localization-trigger module string in `home.dart`.

**Miscellaneous**

- `ProjectBloc` hardcodes the campaign ID `CMP-2026-06-08-000333` when the project type is "SMC-RI", overriding the normal reference-ID-based lookup.

## 2.2.59 — 2026-06-03

- Total wastage (`metrics['stockWastage']`) is now subtracted from the stock balance formula, so wasted stock no longer inflates on-hand counts.
- `stock_balance_executor.dart` no longer persists computed balances to `UserActionLocalRepository` — balances now live purely in the in-memory `StockBalanceCache`. `stock_balance_card.dart` also gained a listener for `TaskModel` changes that triggers a balance refresh, so stock recalculates when tasks change, not only when stock or user-action records change. This is a broader change than "refactor to use cache" implies, since it both removes a persistence path and adds a new reactive trigger.
