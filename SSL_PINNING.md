# SSL Pinning

How certificate pinning works in this app, why each choice was made, and what
to do when the certificate changes.

---

## 1. At a glance

| | |
|---|---|
| **What is pinned** | The issuing intermediate CA, *not* the server leaf |
| **Anchor** | `Sectigo Public Server Authentication CA DV R36`, expires 21 Mar 2036 |
| **Host** | `campaigns.afro.who.int` |
| **Asset** | `apps/health_campaign_field_worker_app/assets/certificates/tls_cert.crt` |
| **Active from** | `AppSecurityLevel.medium` upward, or `AppSecurityFeature.sslPinning` |
| **On failure** | Fails closed. No request is sent unpinned, ever |
| **Rotate with** | `tools/security/rotate_pinned_cert.sh` |
| **Verify with** | `tools/security/test_ssl_pinning.sh` |

---

## 2. How it works

Three files carry the whole mechanism.

**`lib/security/network/ssl_pinning.dart`** builds the client:

```dart
final securityContext = SecurityContext(withTrustedRoots: false);
securityContext.setTrustedCertificatesBytes(certData.buffer.asUint8List());

final httpClient = HttpClient(context: securityContext)
  ..badCertificateCallback = (cert, host, port) {
    debugPrint('Bad certificate for $host');
    return false;
  };
```

`withTrustedRoots: false` is the load-bearing line: it discards the platform
trust store, so the device's system **and user** CA stores are irrelevant. Only
the bundled certificate can terminate a chain. `badCertificateCallback` always
returns `false`, because a pinned client that accepts a bad certificate is not
pinned at all.

This works with a CA rather than a self-signed root because BoringSSL accepts a
*partial chain* — a non-self-signed trust anchor is valid. Verified directly:
the OpenSSL CLI rejects that by default, Dart accepts it.

**`lib/data/remote_client.dart:66`** applies the client to Dio. `_init()` first
installs an ordinary `HttpClient` (system trust, bad certs rejected), which
`enableSSLPinning()` then replaces.

**Startup order matters and is correct.** `main.dart:103` awaits
`enableSSLPinning()` *before* `_dio` is exposed at line 105, and nothing makes a
network call earlier — `envConfig.initialize()` and `AppSecurity.configure()`
are local. The background isolate does the same at
`background_service.dart:122`. Both isolates pin independently, because an
unpinned sync isolate would defeat pinning for exactly the traffic that carries
campaign data.

### When it is active

Pinning is a selectable feature, not a global:

| Level | SSL pinning |
|---|---|
| `low` | off |
| `medium` | on |
| `high` | on |

Production runs `high` (`main.dart:76`). `AppSecurityFeature.sslPinning` can
also be selected individually via `AppSecurity.configure(features: {...})`.

### On failure

If the asset is missing or malformed, `createPinnedHttpClient` does **not**
return `null` — that value means "pinning not requested" and would make the
caller keep its unpinned default client, silently restoring system CA trust.
Instead it records the reason on `AppSecurity.sslPinningFailure` and returns a
client that refuses everything: `badCertificateCallback` blocks TLS, and
`connectionFactory` fails before a socket opens, which also blocks cleartext.

---

## 3. Two layers, different jobs

Pinning is often confused with the network security config. They stack:

| | `network_security_config.xml` | Pinning |
|---|---|---|
| Blocks cleartext HTTP | yes | incidentally |
| Ignores user-installed CAs | yes, in release | yes |
| Ignores the *system* CA store | no | yes |
| Survives a compromised public CA | no | yes |
| Applies to the background isolate | yes | yes, separately |

The config is the cheap, declarative floor. Pinning is the part that survives a
mis-issued certificate from a CA the platform trusts.

---

## 4. Threat model

**Defends against:** an attacker on the network path with a certificate the
device would otherwise trust — a planted device CA (a Burp/mitmproxy root
installed on a managed or borrowed handset), a corporate TLS-inspecting proxy,
or a genuine mis-issuance by any public CA other than the pinned one.

**Does not defend against:**

- **A compromised or malicious device.** Pinning is client-side. On a rooted
  handset the APK can be repackaged with a different anchor, or the check hooked
  out with Frida. Root and hook detection exist for that, and are themselves
  bypassable. Pinning protects *users from network attackers*; it does not
  protect the server from the user.
- **A compromised server.** Pinning authenticates the transport, not the API.
- **A mis-issuance by the pinned CA itself** for this hostname.

---

## 5. Design decisions

### 5.1 Pin the issuing CA, not the leaf

| | Merits | Demerits |
|---|---|---|
| **Leaf** (previous) | Tightest possible trust: exactly one certificate | Expires in months. Every renewal takes every installed build offline. No renewal survives without a coordinated release |
| **Issuing CA** (current) | ~10 years of headroom. Leaf renewals need no app update at all | Trusts any certificate that CA issues **for this hostname**. Breaks if the CA changes |
| **Root CA** | Also survives an intermediate change | Trusts far more of that CA's output. Barely tighter than system trust for a large CA |

**Chosen: issuing CA.** Hostname verification still applies to the leaf, so a
certificate for another host is rejected. Abusing a DV CA requires proving
control of `campaigns.afro.who.int`, a far higher bar than installing a
certificate on a device — which is the attack pinning exists to stop.

The honest cost: trust widened from one certificate to one CA. For a fleet that
cannot be updated on demand, ~10 years of headroom is worth more than that
marginal tightening.

### 5.2 Trust anchors, not manual fingerprint comparison

| | Merits | Demerits |
|---|---|---|
| **Trust anchor** (current) | BoringSSL does chain building, expiry and hostname checks. Small, hard to get wrong | Pins certificate *identity*, not key. A renewal reusing the same key still needs the same CA |
| **SPKI hash check** | Survives renewal when the key is reused. Supports a not-yet-deployed backup pin | Dart does not expose the SPKI; requires DER parsing. Hostname and expiry must be re-implemented by hand — easy to get subtly wrong |

**Chosen: trust anchors.** Hand-rolled certificate validation is a classic
source of silent, total failures.

### 5.3 Fail closed, without crashing

| | Merits | Demerits |
|---|---|---|
| **Fall back to default client** | App keeps working | Silently loses pinning. A packaging error becomes an undetected security regression. **Rejected** |
| **Let it throw** | Unambiguous | Startup crash, no diagnostic, blocks all local work over a bad file |
| **Refusing client** (current) | Nothing sent unpinned. App still runs. Reason recorded and typed | Network appears dead, and to a field worker that resembles poor connectivity |

**Chosen: refusing client.** See §7 for the remaining gap this leaves.

### 5.4 One anchor, bundled in the APK

Bundling means a pin change requires a release. There is **no way to push a pin
to an installed app.** That is the central constraint, and §6 is how it is
managed.

Two anchors from the *same* chain are redundant — trust is the union, so a root
supersedes its own intermediate. Two anchors from *different* CAs are a genuine
backup pin, which is what `--add` exists for.

---

## 6. Offline-first consequences

This matters more here than in a connected app.

**Field devices do not update on demand.** A build can be in use for months.
Any pin change must therefore ship and be *adopted* before the server presents
a certificate the old build does not trust. Reversing that order takes every
un-updated install offline.

**Fail-closed means sync stops, not that the app stops.** Local data entry,
local queries and the local queue keep working; the app is offline-first by
design. That is what makes the refusing client an acceptable failure mode
rather than an outage.

**But a sync outage is not benign.** Unsynced records accumulate on the handset.
A device lost, wiped or reinstalled before sync resumes loses that data. The
longer pinning is broken, the larger the exposure — so "the app still works"
must not be mistaken for "there is no incident".

**A pin failure is indistinguishable from no signal.** To the worker, both are
"sync isn't working". This is the weakest point in the current design and the
first item in §7.

**Rotation windows must be generous.** Not days. Ship the overlap build, confirm
adoption from the field, and only then let the server move.

---

## 7. Rotation

Routine leaf renewal needs **nothing** — that is the point of pinning the
issuer.

A CA change needs this sequence:

```bash
# 1. build a bundle trusting both the outgoing and incoming CA
./tools/security/rotate_pinned_cert.sh --anchor intermediate --add --write

# 2. verify
./tools/security/test_ssl_pinning.sh

# 3. rebuild and release, then WAIT for field adoption

# 4. only now let the server switch to the new CA

# 5. once adopted, drop the superseded anchor
./tools/security/rotate_pinned_cert.sh --anchor intermediate --write
```

Steps 3 and 4 are ordered deliberately. `rotate_pinned_cert.sh` refuses to write
an anchor that does not validate the live server, using the same semantics as
the app (`-partial_chain`, system store excluded), so a wrong anchor cannot
reach a build.

---

## 8. Verification

`tools/security/test_ssl_pinning.sh` — 8 checks:

1. The certificate is present and parseable.
2. **Every** anchor in the bundle is valid, with a 30-day warning horizon.
3. A certificate name covers the `BASE_URL` host (skipped for a CA pin, where
   hostname verification applies to the leaf at runtime).
4. The live server chain validates against the pin, with the app's own
   semantics.
5. Pin type and rotation headroom.
6. The release network security config does not trust user CAs.
7. The asset is actually bundled in the built APK.
8. The failure path does not fall back to an unpinned client.

Checks 2 and 4 are the ones that catch a real outage before release. Check 4
must keep `-no-CApath -no-CAstore`: without them it consults the system trust
store and passes against *any* CA, proving nothing.

---

## 9. Future improvements

Ordered by value for this app, not by sophistication.

### 9.1 Tell the worker that an update is required — highest value, low cost

`AppSecurity.sslPinningFailure` is already recorded, and a pinned-client
handshake failure is distinguishable from a socket timeout. Today both surface
as a generic sync error, so a pin problem is invisible until someone inspects a
device. Surfacing "this app version can no longer reach the server — please
update" converts a silent multi-week outage into an actionable message. This is
the single biggest gap.

### 9.2 Run the checks in CI, and diary the expiry

`test_ssl_pinning.sh` needs only `openssl` and network for its critical checks.
Running it per release blocks a build whose pin no longer matches the live
server. Separately, put the anchor expiry in whatever calendar the team actually
reads — a 2036 date will otherwise be forgotten.

### 9.3 Carry a second, independent CA anchor

Adding an anchor from a different CA ahead of any migration means a provider
change needs no emergency release. Cost: trust widens to two CAs. Worth it only
if a CA change is plausible; ask WHO's platform team how their certificates are
procured before deciding.

### 9.4 Distinguish "cannot reach server" from "pin rejected" in telemetry

Record the failure locally and include it in whatever diagnostics bundle
support collects. Reporting it home is chicken-and-egg while the pinned channel
is the broken one; a separate unpinned channel for that would be a new,
low-value attack surface.

### 9.5 Consider SPKI pinning only if renewals start reusing keys

Would let a renewal be trusted without shipping anything. Costs hand-rolled
validation (§5.2). Not worth it while the CA pin gives ~10 years.

### 9.6 Signed remote pin distribution — the real fix, probably not worth it

Fetch a pin set signed by an app-embedded key, verify, cache, use. This is the
only approach that updates a released fleet's pins without a release. It also
adds a signing key to manage, a distribution channel to secure, and a rollback
story. Revisit only if CA churn proves frequent.

### 9.7 Housekeeping

- `DioClient.disableSSLPinning()` (`remote_client.dart:82`) is never called. It
  is a live way to silently unpin the app. Delete it, or gate it behind
  `kSecurityTestMode`.
- Monitor the host's certificate externally (any CT-log or uptime monitor) so
  ops learn about a CA change from tooling rather than from field reports.

---

## 10. Known limitations

- A pin change cannot reach an installed app. Releases must lead server changes.
- Trust is one CA. A change of CA provider breaks every un-updated install.
- Pinning is bypassable on a device the attacker controls (§4).
- Pinning applies to the whole Dio client: any other host reached through it
  must chain to the same CA, or it will fail.
- The pin authenticates the transport only, not the API or its data.
