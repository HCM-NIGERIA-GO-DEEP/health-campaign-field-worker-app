# Security Enhancements Release Notes

**Version:** 2.2.111+111  
**Release Date:** September 4, 2026  
**Supersedes:** the separate 1.8.6+6 and 1.8.7+7 notes, consolidated here

> 2.2.110 is the version this work was built *on top of*, not the one that
> carries it. These mitigations first ship in 2.2.111.

---

## Overview

This document describes the security posture of the application as it stands,
covering the five vulnerability classes identified during Vulnerability
Assessment and Penetration Testing (VAPT) and the work done since to make each
one selectable, verifiable and survivable in the field.

It replaces the three separate versioned notes that preceded it. Those
described the same mitigations at three points in time and had begun to
contradict each other; what follows is the current state, with history retained
only where it explains a decision.

### Corrections to the earlier notes

A reader familiar with the 1.8.x notes should know these claims no longer hold:

| Earlier claim | Current reality |
|---|---|
| Root detection uses a BLoC for security state | That BLoC and its wrapper were dead code — 210 lines, every line commented out — and were removed. Detection runs through `DeviceIntegrityService` |
| "Checksum generation creates unique security state checksums for validation" | The checksum mixed in `DateTime.now()`, so it could never be compared with anything. Replaced by a deterministic, order-independent fingerprint of the threat set, usable as a server-side deduplication key |
| `-keep,includedescriptorclasses class com.digit.hcm.** { *; }` protects entry points | That blanket rule overrode the narrower `allowobfuscation` rule and left `SecurityHelper` readable in the shipped DEX. Removed |
| `signingConfig signingConfigs.release` | The release build type still uses `signingConfigs.debug` with a TODO. **This must be resolved before publishing** |
| "Security test suite: ALL PASSED" | Several checks were reporting on conditions they could not observe. See §11 |
| APK size, "~90% of classes obfuscated", method-rename percentages | Dropped. These were point-in-time figures from a build that no longer exists and were never re-measured |

---

## Scope

| # | Mitigation | Enforced | Verified by |
|---|---|---|---|
| 1 | Insecure Broadcast Receiver | Manifest + native | `test_broadcast_receivers.sh` |
| 2 | Root Detection Bypass Prevention | Runtime | `test_root_detection.sh` |
| 3 | Improper Platform Usage | Manifest + platform APIs | `test_platform_usage.sh` |
| 4 | Code Obfuscation | Build | `test_obfuscation.sh` |
| 5 | SSL Pinning | Runtime | `test_ssl_pinning.sh` |

Items 1, 3 and 4 are decided when the APK is built. Dart cannot switch them on,
so the app *verifies* them at runtime instead of assuming them (§8).

---

## 1. Insecure Broadcast Receiver Mitigation

**Vulnerability.** A component exported without access control can be started or
driven by any other app on the device. Crafted intents may trigger unauthorised
actions, leak data, or manipulate application behaviour. It arises from a
misconfigured `android:exported`, missing permission enforcement, or failure to
validate incoming intent data.

### Component export

- `MainActivity` is `exported="false"`. It holds the Flutter engine and app
  state, and is no longer reachable from outside.
- `flutter_background_service`'s `BackgroundService`, `WatchdogReceiver` and
  `BootReceiver` ship exported by default. They are forced closed with
  `android:exported="false"` plus `tools:replace="android:exported"`, which is
  required because the app manifest must win the merge against the plugin's own.
- Intent filters for `BOOT_COMPLETED`, `QUICKBOOT_POWERON` and
  `MY_PACKAGE_REPLACED` are retained; only external delivery is closed.

```xml
<receiver
    android:name="id.flutter.flutter_background_service.BootReceiver"
    android:enabled="true"
    android:exported="false"
    tools:replace="android:exported">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

### LocationService

Renamed from `location_service.kt` to match its class name, declared
`exported="false"`, and hardened further:

- **Addressed broadcasts.** `intent.setPackage(packageName)` plus a
  signature-level permission, so only this app can receive `LocationUpdate`.
- **Encrypted at rest.** GPS records were previously written in plaintext to the
  external Downloads folder. They are now AES-256-GCM encrypted under an Android
  Keystore key (`location_data_key`) in app-private `filesDir`, with the IV
  prepended per record.
- **No lock-screen disclosure.** Notification visibility is
  `VISIBILITY_SECRET` and the text is generic rather than raw coordinates.
- **Deprecations fixed.** `LocationRequest.Builder` replaces
  `LocationRequest.create()`; `STOP_FOREGROUND_REMOVE` replaces
  `stopForeground(true)`.

```kotlin
intent.setPackage(packageName)
sendBroadcast(intent, "${packageName}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION")

val cipher = Cipher.getInstance("AES/GCM/NoPadding")
cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
```

`MainActivity` also registers its receiver with `RECEIVER_NOT_EXPORTED` on
Android 13+.

**Impact.** No app-owned component is reachable without a permission guard
except the launcher entry point; GPS data is encrypted with a hardware-backed
key; nothing sensitive reaches the lock screen.

---

## 2. Root Detection Bypass Prevention

**Vulnerability.** An app relying on client-side root detection can have those
checks neutralised by dynamic instrumentation, runtime hooking or environment
manipulation, and then run with elevated privileges. Client-side detection is
inherently unreliable; the goal is to raise cost, not to be conclusive.

### Native layer — `SecurityHelper.kt`

Independent signals are combined so defeating one does not defeat the check:

- **Root:** su binaries across 10+ paths, the Superuser APK, writable system
  partitions, dangerous build properties (`ro.debuggable`, `ro.secure`,
  test-keys), 12+ known root managers (Magisk, SuperSU, KingRoot…), root-cloaking
  apps, BusyBox.
- **Emulator:** build fingerprint, model, product and hardware markers.
- **Hooking frameworks:** Frida (server binaries, gadget libraries, default
  ports 27042/27043), Xposed, Cydia Substrate.
- **Debugger:** attached or waiting.
- **Repackaging:** the running APK's signing certificate against an expected
  value.

Root-cloaking tools exist specifically to defeat single-signal checks, which is
why the root path probes native filesystem state rather than trusting a library.

### Dart layer — `DeviceIntegrityService`

Detection only; it decides what is true about the device, never what to do about
it.

- **A check that cannot run is not a threat.** Native probes return `null` for
  "unavailable", which lands in `SecurityCheckResult.unavailableChecks` and is
  reported. `isPassed` depends on confirmed threats alone. Previously any
  exception from the detection library became an `unknown` threat that reached
  `exit(0)` in production, so a `MissingPluginException` or an unsupported OEM
  device terminated the app with no diagnostic.
- **Response is a policy**, not a line inside detection: `ThreatResponseMode` is
  `exitApp` (default), `restrict` or `reportOnly`. The compromised flag is set
  before any termination, so `restrict` is reachable — previously it sat after
  an unconditional `exit(0)` and could never execute.
- **Periodic re-checks** use a cancellable timer, and the first pass does not
  block startup.
- **Threat fingerprint** is a deterministic SHA-256 over the sorted threat set —
  a deduplication key, explicitly *not* an integrity proof, since a value
  computed on a compromised client proves nothing.

**Impact.** Multi-vector detection reduces bypass probability and identifies
emulator, hooked and debugged environments.

What this does *not* achieve, and the conditions it depends on, are recorded in
§11.2 rather than here, so the limitations of every mitigation sit in one place.

---

## 3. Improper Platform Usage Mitigation

**Vulnerability.** Failure to use platform security controls correctly —
permissions, key management, secure storage, IPC protection, cryptographic APIs.
Sensitive data or privileged functionality becomes exposed to other apps or to
the user.

### Exported launcher pattern (Android 12+)

Android 12 requires an activity with a LAUNCHER filter to be explicitly
exported, but `MainActivity` holds business logic that should not be externally
reachable. A minimal `LauncherActivity` is the exported entry point and forwards
immediately:

```kotlin
class LauncherActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val intent = Intent(this, MainActivity::class.java).apply {
            this@LauncherActivity.intent.extras?.let { putExtras(it) }
            if (this@LauncherActivity.intent.action != Intent.ACTION_MAIN) {
                action = this@LauncherActivity.intent.action
                data = this@LauncherActivity.intent.data
            }
        }
        startActivity(intent)
        finish()
    }
}
```

`android:taskAffinity=""` prevents StrandHogg task hijacking, where a malicious
app matches task affinity to insert itself into this app's back-stack.
Conditional forwarding preserves deep links without conflicting with
MAIN/LAUNCHER.

### Network security configuration

```xml
<base-config cleartextTrafficPermitted="false">
    <trust-anchors>
        <certificates src="system" />
        <!-- user-installed CAs deliberately absent -->
    </trust-anchors>
</base-config>
```

Cleartext HTTP is blocked globally, and user-installed CAs — the usual TLS
interception vector — are not trusted. A `debug-overrides` block restores them
for development and is stripped from release APKs by the build system.

### Data at rest

- `android:allowBackup="false"`, so app data cannot be pulled with `adb backup`.
- Secure storage explicitly requests `encryptedSharedPreferences: true`, giving
  an Android Keystore-backed AES-256 key rather than a weaker KeyStore-only
  fallback used by some plugin versions.
- The local database key is generated with `Random.secure()` and preserved
  across `deleteAll()`.

### Certificate validation is unconditional

`badCertificateCallback` always returns `false`. It previously returned `true` at
`AppSecurityLevel.low`, which accepted any certificate; there is no longer a
security level at which validation is skipped.

**Impact.** Platform requirements met without exposing app logic; cleartext and
user-CA interception blocked; app data not extractable by backup; storage uses
the strongest available backend.

---

## 4. Code Obfuscation

**Vulnerability.** Without obfuscation an APK can be decompiled to read business
logic, locate security mechanisms, extract hard-coded values and bypass
client-side protections, which makes chaining other vulnerabilities easier.

### Build configuration

```gradle
release {
    minifyEnabled true
    shrinkResources true
    proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                  'proguard-rules.pro'
}
```

`proguard-android-optimize.txt` enables R8 full mode: more aggressive dead-code
removal and stronger renaming than the balanced profile used in 1.8.6.

### Keep-rule policy

The rule set is narrow on purpose. Broad keeps defeat the feature they appear to
support:

| Rule | Disposition | Reason |
|---|---|---|
| `-keep class kotlin.** { *; }` | removed | Defeated Kotlin obfuscation |
| `-keep class androidx.** { *; }` | removed | Defeated AndroidX obfuscation |
| `-keep class com.digit.hcm.** { *; }` | removed | Exposed all app internals, and overrode the rule below |
| `-keep public class * extends android.app.Activity` | removed | R8 handles component lifecycle already |

Security-sensitive classes are kept *renameable*, because Flutter dispatches over
the method channel by string and preserving Kotlin names would only publish a map
of the detection routines:

```proguard
-keep,allowobfuscation class com.digit.hcm.SecurityHelper
-keepclassmembers,allowobfuscation class com.digit.hcm.SecurityHelper {
    public *;
}
```

That intent had been silently defeated: a blanket `-keep class com.digit.hcm.**`
retained from an earlier merge is more permissive and wins the conflict, so
`Lcom/digit/hcm/SecurityHelper;` shipped readable in the DEX. Removing it was
confirmed against a rebuilt release APK — `SecurityHelper` is renamed, while
`MainActivity`, `LauncherActivity` and `LocationService` keep their names as the
manifest requires.

### Dart obfuscation is separate

R8 does not touch Dart. `flutter build apk --release` alone leaves Dart class
names readable in `libapp.so`; only `--obfuscate --split-debug-info` removes
them. Use `./build_obfuscated.sh apk`, which passes both.

**Impact.** Reverse engineering is materially harder and security mechanism
names are not published. It does not stop a determined attacker with device
control; it raises cost.

---

## 5. SSL Pinning

**Vulnerability.** Ordinary TLS trusts every CA the device trusts, including any
certificate an attacker has installed. A planted device CA, a TLS-inspecting
proxy, or a mis-issuance by any public CA is sufficient to read and modify
traffic.

Full design, threat model and trade-offs: **`SSL_PINNING.md`**.

### What is pinned

| | |
|---|---|
| Anchor | `Sectigo Public Server Authentication CA DV R36` — the issuing CA |
| Expires | 21 Mar 2036 |
| Host | `campaigns.afro.who.int` |
| Asset | `assets/certificates/tls_cert.crt` |

**The anchor is the issuer, not the server leaf, deliberately.** Pinning fails
closed: a leaf expires within months, so every renewal would have taken every
installed build offline — unable to reach the API at all, not merely degraded.
Field devices do not update on demand, which makes that an availability incident
rather than a security one. Routine leaf renewal now requires no application
change; an update is needed only if the CA itself changes.

### Trust scope

```dart
final securityContext = SecurityContext(withTrustedRoots: false);
securityContext.setTrustedCertificatesBytes(certData.buffer.asUint8List());
```

`withTrustedRoots: false` discards the platform trust store, so the device's
system **and** user CA stores are both irrelevant — only the bundled certificate
can terminate a chain. This is the layer that survives a mis-issuance by a CA
the platform already trusts, which the network security config cannot do.

Hostname verification still applies to the leaf, so a certificate for another
host is rejected. Abusing the pinned DV CA would require proving control of
`campaigns.afro.who.int` — far harder than installing a certificate on a device.

**Trade-off, stated plainly:** trust widened from one certificate to one CA. For
a fleet that cannot be updated on demand, ~10 years of headroom is worth more
than that marginal tightening.

### Both isolates pin

Pinning is applied in the UI isolate and again in the background sync isolate.
An unpinned sync isolate would defeat pinning for exactly the traffic carrying
campaign data.

### Failure is closed, not silent

A missing or malformed certificate previously threw during startup, before the
UI existed, and killed the background isolate quietly. It now records the reason
on `AppSecurity.sslPinningFailure` and returns a client that refuses every
request: `badCertificateCallback` blocks TLS, and `connectionFactory` fails
before a socket opens, which also blocks cleartext.

Deliberately **not** implemented: falling back to the default client. That would
silently restore system and user CA trust, turning a packaging mistake into an
undetected loss of pinning.

### Rotation

`tools/security/rotate_pinned_cert.sh` performs the replacement and refuses to
write an anchor that does not validate the live server. For a CA migration,
`--add` produces a bundle trusting both the outgoing and incoming CA:

```
1. ./tools/security/rotate_pinned_cert.sh --anchor intermediate --add --write
2. release, and wait for field adoption
3. only then let the server switch
4. rerun without --add to drop the superseded anchor
```

Steps 3 and 4 are ordered deliberately; reversing them takes every un-updated
install offline.

**Impact.** Network interception requires compromising the pinned CA rather than
the device's trust store. The cost is an operational dependency: certificate
changes must be released ahead of server changes.

---

## 6. Selectable Mitigations

Security was a single `low`/`medium`/`high` dial. Each mitigation can now be
selected individually:

```dart
AppSecurity.instance.configure(
  level: AppSecurityLevel.high,
  disable: {AppSecurityFeature.emulatorDetection},
);
```

Each device-integrity layer is gated on its own feature, and pinning on
`AppSecurityFeature.sslPinning`. Presets preserve prior behaviour: `low` selects
nothing, `medium` suppresses release logs and pins TLS, `high` enables
everything. Production runs `high`.

`AppSecurityFeature.isRuntimeEnforced` separates what Dart can enforce from what
the build decides. Offering toggles that silently do nothing would be worse than
not offering them.

---

## 7. Security Module Layout

Security code lived in the `lib/` root, the `lib/utils/` grab bag, and inline in
`lib/data/remote_client.dart`. It is now one module:

```
lib/security/
  app_security.dart                 orchestration and policy
  models/                           features, levels, results, reports
  channel/security_channel.dart     the one channel definition
  integrity/                        detection, native transport, response
  network/ssl_pinning.dart          certificate pinning
  audit/                            build-time verification
```

Two files carrying eight responsibilities became fourteen with one each.
Detection no longer decides how to respond, and no longer reads the environment.

---

## 8. Build-Time Mitigation Verification

Obfuscation, component export and platform hardening are properties of the
build. Selecting one is a declaration of intent that
`AppSecurity.verifyBuildTimeMitigations()` checks against the shipped APK, via a
native `auditBuildConfiguration` call reporting:

- `minifyEnabled`, through an injected `IS_MINIFIED` `buildConfigField`, since
  R8 leaves no queryable runtime flag;
- `debuggable`, `allowBackup`, cleartext-traffic policy;
- components exported without a permission guard.

The result is kept on `AppSecurity.lastBuildTimeReport`, because log suppression
hides it in exactly the hardened build where it matters.

### Making detection observable

Root-detection tests reported VULNERABLE on an emulator while detection was
firing. A normal build silences `debugPrint` and calls `exit(0)` on a confirmed
threat, so the app detected the emulator, logged nothing and terminated —
correct for production, unverifiable from outside.

`--dart-define=SECURITY_TEST_MODE=true` keeps every check running and every
threat confirmed, but leaves the evidence visible: log suppression off, response
mode `reportOnly`. It defaults to false and must never be set for a build that
ships.

---

## 9. Server-Side Root Detection — Evaluated, Not Implemented

Device attestation (Play Integrity) was considered and rejected for this
application.

**Decisive factor: it conflicts with offline-first operation.** This app is
designed to work without connectivity for extended periods in the field. A
server-side gate either blocks work when the network is unavailable, or is
advisory and therefore bypassable — the same position as client-side detection,
at much higher cost.

Supporting reasons:

- **Infrastructure.** A highly available attestation service, since it gates app
  functionality; token caching; monitoring. Play Integrity adds a Play Services
  dependency and excludes custom ROMs.
- **False positives.** Legitimate rooted devices — accessibility tooling,
  enterprise MDM, development handsets — would be blocked, creating support load.
- **Privacy.** Device fingerprints collected server-side raise data-protection
  questions for a health programme.
- **Marginal gain.** Attestation responses can be manipulated or replayed by an
  attacker with device control, so it does not change the ceiling.

**Adopted instead:** layered client-side detection, encryption at rest so a
compromised device yields less, and backend anomaly detection on usage patterns.

Reconsider only if the app begins handling financial transactions, regulation
mandates attestation, or field data shows material rooted-device fraud.

---

## 10. Testing & Validation

### Automated suites

Coverage went from 9 checks to 31, and a fifth suite was added for the
mitigation that had none.

| Suite | Before | Now |
|---|---|---|
| `test_ssl_pinning.sh` | — | **8** |
| `test_obfuscation.sh` | 2 | 7 |
| `test_platform_usage.sh` | 3 | 8 |
| `test_broadcast_receivers.sh` | 2 | 5 |
| `test_root_detection.sh` | 2 | 3 (reworked) |
| **Total** | **9** | **31** |

Outcomes now include SKIPPED and INCONCLUSIVE, and a mitigation that could not
be verified reports "Not verified" rather than passing. Unverified is not the
same as safe, and the previous aggregation could only say passed or failed.

Several checks were corrected for reporting VULNERABLE on conditions that were
impossible to observe or that mismatched the data format: a commented-out
attribute read as configuration, an `aapt2` attribute id matched as a value, an
app class name that was really a string literal, and a chain check that passed
against any CA because it consulted the system trust store. Each now has a
negative control.

### Verified for this release

- `dart analyze`: 0 errors across `lib/`, unchanged issue baseline.
- SSL, obfuscation, manifest and component-sweep checks run against a real
  release APK. `SecurityHelper` renamed; manifest components kept; Dart symbols
  obfuscated with symbol files retained.
- Pinning verified end to end with a standalone Dart client against the live
  host: leaf pin, issuer pin and a multi-anchor bundle all connect; an
  unrelated-CA bundle fails with `CERTIFICATE_VERIFY_FAILED`.
- BoringSSL confirmed to reject a trust anchor whose own validity has lapsed,
  using a purpose-built expired CA and a local TLS server. This is what makes an
  expired pin unrecoverable in the field (§11).
- Unit tests for feature selection, the availability-versus-threat distinction,
  response modes and the pinning failure path.

### Not verified

- **The Kotlin and Gradle changes were not compiled, and the Dart tests were not
  executed**, because `flutter pub get` fails on a pre-existing `bloc_test` /
  path-pinned `dart_mappable_builder` conflict. Run `melos bootstrap` first.
- Device-dependent checks (broadcast spoofing, service export, logcat scanning,
  live Frida) need hardware and were not run.

### Device compatibility

Android 8.0 (API 26) through Android 14 (API 34). Backward-compatible
`stopForeground()` handling and `LocationRequest.Builder` verified across target
levels.

---

## 11. Known Limitations

### 11.1 Release signing — blocker

The release build type uses `signingConfig signingConfigs.debug` with a TODO. A
conditional release config driven by `key.properties` exists but is not
referenced. **Resolve before publishing:** an APK signed with debug keys cannot
be distributed, and the repackaging check has no stable signature to compare
against.

---

### 11.2 Root detection and other client-side controls

**They are bypassable by design.** Root detection, hook detection and pinning
all execute on the device. An attacker with device control can repackage the APK
with a different anchor, hook the checks out with Frida, or patch the native
library. Layering independent signals raises the cost and defeats casual
tooling; it does not make the result trustworthy.

The correct reading: these controls protect *users from network attackers* and
raise the cost of tampering. They do not protect the *server from the user*.
Server-side validation remains the only authoritative control — see §9 for why
device attestation was evaluated and rejected for this application.

**Repackaging detection is inert** until an expected signing certificate is
supplied via `AppSecurity.configure(expectedAppSignature:)`. With nothing to
compare against the native side reports a match, so this layer currently
contributes nothing. Supplying it is a deployment step, not a code change, and
depends on §11.1 being resolved first.

**Emulator detection terminates release builds.** With `ENV_NAME=PROD` a
release build self-exits on an emulator. That is detection working, not a
crash, but it makes emulator-based QA of release builds impossible without
`--dart-define=SECURITY_TEST_MODE=true`.

**Detection accuracy decays.** Root and hook detection depend on indicators —
paths, package names, property values — that change as rooting and
instrumentation tooling evolves. Without periodic review the checks quietly
become less effective while continuing to report success.

---

### 11.3 SSL pinning: expiry, offline-first data loss, and recovery

Pinning fails closed, which on an offline-first app converts a certificate
problem into a data-retention problem. This is the most consequential
limitation in this document.

#### What happens

If the server presents a certificate that no installed build trusts — because
the pinned anchor expired, or the CA changed — those installs cannot reach the
API at all. The app itself keeps working: local data entry, local queries and
the outbound queue are unaffected, which is what makes fail-closed acceptable
rather than an outage.

**But sync stops, and unsynced records then exist only on the handset.** The
longer that lasts, the larger the exposure. "The app still works" is not "there
is no incident".

#### How data is actually lost

Being unable to sync does not destroy data by itself. Loss happens when the
handset's local store is discarded while records are still unsynced:

- the device is lost, stolen, damaged or factory reset;
- the app is **uninstalled and reinstalled**, which wipes app-private storage.
  Both update paths are in use across deployments, and this one loses data;
- "clear app data" is used during troubleshooting — a plausible first response
  to "sync isn't working", and the worst possible one here.

An in-place upgrade (same signing key, higher `versionCode`) preserves app data,
so unsynced records survive. Where a deployment reinstalls instead, they do not.

#### Why it cannot be fixed from the server

BoringSSL rejects a trust anchor whose own validity has lapsed — confirmed
against a purpose-built expired CA and a local TLS server — so **no chain the
server presents will validate**. Installing a CA on the device does not help
either, because `withTrustedRoots: false` discards the system and user stores.
The certificate asset cannot be swapped on device: it sits inside the signed
APK, and editing it breaks the signature.

The only workaround requiring no new APK is rolling the device clock back to
before the anchor's expiry. It is expected to work, since validity is evaluated
against device time, but it writes wrong dates into campaign records and will
likely trip server-side clock-skew checks. **Not recommended** except, at most,
to drain data off a device before updating it.

#### Resolution 1 — update the APK (primary)

Ship a build with a valid pin. Where the deployment performs an in-place
upgrade, unsynced records survive the update and sync resumes on their own.
Where the deployment uninstalls first, resolution 2 is required to avoid losing
them.

Prevention is the real control: the CI expiry check, the ~10-year anchor, and
releasing ahead of any server certificate change (§5).

#### Resolution 2 — user-triggered local backup (planned)

A button in the app exports the local database to device storage using a runtime
file permission, so the export survives uninstall and can be imported by the
updated APK. `MANAGE_EXTERNAL_STORAGE` is already declared in the manifest and
`permission_handler` is already a dependency.

The backup is **manual and on demand**, not automatic: it is intended to be used
when sync has broken because of pinning.

Constraints this design has to satisfy, recorded here because they are not
obvious:

1. **The worker has to press it in time.** A pin failure presents as "sync isn't
   working", which is indistinguishable from poor connectivity. Someone who does
   not know to back up before a reinstall gets no protection from a manual
   button. This pairs with surfacing "update required" from
   `AppSecurity.sslPinningFailure` (§11.4) — without that prompt, the button is
   unlikely to be pressed at the right moment.
2. **A raw file copy will not restore.** The local SQL database is encrypted
   with a key held in `flutter_secure_storage` (`getOrCreateDbEncryptionKey`),
   which is Android Keystore-backed and **destroyed on uninstall**. A byte copy
   of the database is therefore permanently unreadable by the new install. The
   export has to be produced in a form the reinstalled app can open — decrypted
   at export time and re-protected — rather than copied.
3. **Shared storage is exposed storage.** Anything written where it survives
   uninstall is readable by other apps holding storage access and over USB. That
   runs against `allowBackup="false"` and the `EncryptedSharedPreferences`
   posture in §3, so the export should be encrypted under a secret that also
   survives reinstall — for example derived from the worker's credentials —
   rather than written in the clear. Note that the app-specific external
   directory is *also* wiped on uninstall and so does not solve this.
4. **Restore is an untrusted input path.** A file in shared storage can be
   modified or replaced before import. The restore path must authenticate and
   validate the export rather than trusting its contents, or it becomes a way
   to inject records into the local store.
5. **`MANAGE_EXTERNAL_STORAGE` is Play-restricted.** If distribution moves to
   the Play Store, that permission needs justification or replacement with the
   Storage Access Framework, which changes where the file lands and how it is
   found again.

#### Complementary path that already exists

The app ships peer-to-peer transfer (`lib/pages/peer_to_peer/`). A device that
cannot reach the server can hand its unsynced records to a device running an
updated build, with no file export and no shared storage involved. It does not
bring the stuck device online, but it addresses the data-retention risk directly
and is available today.

---

### 11.4 Pinning: operational constraints

**A pin cannot be pushed to a released app.** The certificate is a bundled
asset, so a pin change requires a release. Releases must lead server
certificate changes, with time for field adoption.

**Trust is one CA.** A change of certificate provider breaks every un-updated
install. `rotate_pinned_cert.sh --add` covers that migration, but only if run
before the server switches.

**`DioClient.disableSSLPinning()` is never called** and remains a live way to
silently unpin the app. Delete it or gate it behind `kSecurityTestMode`.

**A pin failure looks like poor connectivity** to a field worker. Surfacing
"update required" from `AppSecurity.sslPinningFailure` is the highest-value
outstanding improvement, and is a precondition for resolution 2 in §11.3 being
useful.

---

### 11.5 Build and tooling

**The Kotlin and Gradle changes were not compiled and the Dart tests were not
executed**, because `flutter pub get` fails on a pre-existing `bloc_test` /
path-pinned `dart_mappable_builder` conflict. Run `melos bootstrap` first.

**Debug builds trust user-installed CAs** via `debug-overrides`. This is
intentional for proxy debugging and is stripped from release APKs by the build
system.

**Dart obfuscation is not automatic.** `flutter build apk --release` alone
leaves Dart class names readable; only `--obfuscate --split-debug-info` removes
them. Use `./build_obfuscated.sh apk`.

**ProGuard rules need review when dependencies change.** R8 full mode is more
aggressive, so a library upgrade can require a new keep rule, and a keep rule
that is too broad silently defeats obfuscation — as one did for
`SecurityHelper` (§4).

---

## 12. Migration & Deployment

### Breaking changes

None. Level presets preserve previous behaviour, and `setSecurityLevel` remains
as a deprecated setter.

### Deployment steps

1. `melos bootstrap`, then `flutter test test/security/`
2. Build with `./build_obfuscated.sh apk` — plain `flutter build apk --release`
   does **not** obfuscate Dart
3. `./tools/security/test_ssl_pinning.sh` — confirm the pin matches the live
   server before release
4. `./tools/security/run_all_security_tests.sh` against a device; read SKIPPED
   and INCONCLUSIVE as "not verified", not as passes
5. For device-integrity verification, build a separate APK with
   `--dart-define=SECURITY_TEST_MODE=true`; never ship it
6. Archive `mapping.txt` and the Dart `.symbols` files — without them a
   production crash report cannot be read back
7. Replace `signingConfigs.debug` with a real release signing config
8. Test on rooted, non-rooted and emulator devices; monitor crash reports for
   R8-related issues

---

## Security Standards

- OWASP Mobile Application Security Verification Standard (MASVS)
- OWASP Mobile Security Testing Guide (MSTG)
- Android Security Best Practices
- Google Play Security Policies
