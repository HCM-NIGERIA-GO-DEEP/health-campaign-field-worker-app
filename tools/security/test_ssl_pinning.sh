#!/bin/bash
# Verifies the SSL Pinning mitigation.
#
# This mitigation had no test before, which is how an expired certificate for
# the wrong host went unnoticed in the repository. Pinning fails closed: if the
# pinned certificate does not match what the server presents, every request
# fails and the app is simply offline. These checks are therefore about the
# certificate agreeing with reality, not just being present.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

EXPIRY_WARN_DAYS=30

echo "==========================================================="
echo " Testing SSL Pinning Mitigation"
echo "==========================================================="
echo ""

APP_DIR=$(sec_app_dir) || { echo "[!] Could not locate the app directory."; exit 1; }
CERT_PATH="$APP_DIR/assets/certificates/tls_cert.crt"
NSC_PATH="$APP_DIR/android/app/src/main/res/xml/network_security_config.xml"

BASE_URL=$(sec_env_value BASE_URL)
BASE_HOST=$(echo "$BASE_URL" | sed -E 's#^[a-z]+://##; s#/.*$##; s#:.*$##')

if ! command -v openssl >/dev/null 2>&1; then
    echo "[!] openssl is required for these checks and was not found."
    exit 1
fi

# Does a certificate name (possibly a wildcard) cover $2?
function name_covers_host() {
    local name="$1"
    local host="$2"
    [ "$name" = "$host" ] && return 0
    case "$name" in
        \*.*)
            local suffix="${name#\*}"                       # ".afro.who.int"
            local head="${host%"$suffix"}"                  # "campaigns" if it matches
            # A wildcard matches exactly one label, so the remainder must be
            # non-empty and contain no dot.
            if [ "$head" != "$host" ] && [ -n "$head" ] && [[ "$head" != *.* ]]; then
                return 0
            fi
            ;;
    esac
    return 1
}

# True when the pinned certificate exists and parses.
#
# Downstream checks gate on this so a single unparseable file reports one root
# cause instead of four symptoms. Without it a corrupt asset also claimed the
# certificate had "already expired", which is not just noisy but wrong, and
# sends whoever reads the report after the wrong problem.
function cert_usable() {
    [ -f "$CERT_PATH" ] || return 1
    openssl x509 -in "$CERT_PATH" -noout >/dev/null 2>&1
}

# True when the pinned certificate is a CA rather than a server leaf.
function pin_is_ca() {
    openssl x509 -in "$CERT_PATH" -noout -ext basicConstraints 2>/dev/null | grep -q 'CA:TRUE'
}

function cert_names() {
    local cert="$1"
    openssl x509 -in "$cert" -noout -subject 2>/dev/null \
        | grep -oE 'CN *= *[^,/]+' | sed -E 's/CN *= *//'
    openssl x509 -in "$cert" -noout -ext subjectAltName 2>/dev/null \
        | grep -oE 'DNS:[^,]+' | sed 's/DNS://' | tr -d ' '
}

function test_certificate_present() {
    sec_begin "Pinned certificate is present and parseable"

    if [ ! -f "$CERT_PATH" ]; then
        sec_fail "No certificate at assets/certificates/tls_cert.crt; pinning cannot work."
        echo ""
        return 1
    fi

    if ! openssl x509 -in "$CERT_PATH" -noout >/dev/null 2>&1; then
        sec_fail "Certificate exists but is not valid PEM."
        echo ""
        return 1
    fi

    local count
    count=$(grep -c 'BEGIN CERTIFICATE' "$CERT_PATH")
    echo "    > Subject : $(openssl x509 -in "$CERT_PATH" -noout -subject 2>/dev/null | sed 's/^subject=//')"
    echo "    > Issuer  : $(openssl x509 -in "$CERT_PATH" -noout -issuer 2>/dev/null | sed 's/^issuer=//')"
    echo "    > Certificates in bundle: $count"
    sec_pass "Certificate is present and parseable."
    echo ""
    return 0
}

function test_certificate_validity() {
    sec_begin "Every pinned certificate is currently valid"
    cert_usable || {
        sec_skip "Certificate missing or not parseable; see the first check."
        echo ""
        return
    }

    # A bundle may hold several anchors during a CA migration. `openssl x509`
    # reads only the first certificate in a file, so checking the file directly
    # would let an expired second anchor pass unnoticed.
    local work
    work=$(mktemp -d) || { sec_skip "Could not create a temporary directory."; echo ""; return; }
    # `n >= 0` drops the comment header: without it those lines land in
    # pin-1.pem, which the pin*.pem glob then treats as a certificate and
    # reports as expired.
    awk -v dir="$work" 'BEGIN { n = -1 }
        /-----BEGIN CERTIFICATE-----/ { n++ }
        n >= 0 { print > (dir "/pin" n ".pem") }
    ' "$CERT_PATH"

    local horizon=$((EXPIRY_WARN_DAYS * 86400))
    local expired=0 expiring=0 total=0
    local f
    for f in "$work"/pin*.pem; do
        [ -f "$f" ] || continue
        total=$((total + 1))
        local subject enddate
        subject=$(openssl x509 -in "$f" -noout -subject 2>/dev/null | sed 's/^subject=//')
        enddate=$(openssl x509 -in "$f" -noout -enddate 2>/dev/null | cut -d= -f2)

        if ! openssl x509 -in "$f" -noout -checkend 0 >/dev/null 2>&1; then
            echo "    > EXPIRED  $enddate  $subject"
            expired=$((expired + 1))
        elif ! openssl x509 -in "$f" -noout -checkend "$horizon" >/dev/null 2>&1; then
            echo "    > expiring $enddate  $subject"
            expiring=$((expiring + 1))
        else
            echo "    > valid    $enddate  $subject"
        fi
    done
    rm -rf "$work"

    if [ "$total" -eq 0 ]; then
        sec_skip "No certificates found in the bundle."
        echo ""
        return
    fi

    if [ "$expired" -gt 0 ]; then
        echo "    > An expired anchor cannot validate anything. If it is the only"
        echo "      anchor, the app cannot reach the server at all."
        sec_fail "$expired of $total pinned certificate(s) have expired."
        echo ""
        return
    fi

    if [ "$expiring" -gt 0 ]; then
        echo "    > Pinning fails closed and an installed build cannot be given a"
        echo "      new pin, so the replacement must ship and be adopted BEFORE"
        echo "      the server rotates. See tools/security/rotate_pinned_cert.sh."
        sec_inconclusive "$expiring of $total pinned certificate(s) expire within $EXPIRY_WARN_DAYS days."
        echo ""
        return
    fi

    sec_pass "All $total pinned certificate(s) are valid beyond $EXPIRY_WARN_DAYS days."
    echo ""
}

function test_certificate_matches_host() {
    sec_begin "Pinned certificate covers the configured BASE_URL host"
    cert_usable || {
        sec_skip "Certificate missing or not parseable; see the first check."
        echo ""
        return
    }

    if [ -z "$BASE_HOST" ]; then
        sec_skip "Could not read BASE_URL from the app .env."
        echo ""
        return
    fi

    if pin_is_ca; then
        echo "    > A CA is pinned, so its subject is an issuer name and is not"
        echo "      expected to match the host. Hostname verification still"
        echo "      applies at runtime, against the leaf the server presents."
        sec_skip "Not applicable to a CA pin; covered by the chain check below."
        echo ""
        return
    fi

    echo "    > BASE_URL host: $BASE_HOST"
    local names
    names=$(cert_names "$CERT_PATH" | sort -u)
    echo "    > Certificate names: $(echo "$names" | tr '\n' ' ')"

    local name
    for name in $names; do
        if name_covers_host "$name" "$BASE_HOST"; then
            sec_pass "Certificate name '$name' covers $BASE_HOST."
            echo ""
            return
        fi
    done

    sec_fail "No certificate name covers $BASE_HOST; pinning will reject every request."
    echo ""
}

function test_certificate_matches_server() {
    sec_begin "Live server chain validates against the pinned certificate"
    cert_usable || {
        sec_skip "Certificate missing or not parseable; see the first check."
        echo ""
        return
    }

    if [ -z "$BASE_HOST" ]; then
        sec_skip "Could not read BASE_URL from the app .env."
        echo ""
        return
    fi

    local work chain
    work=$(mktemp -d) || { sec_skip "Could not create a temporary directory."; echo ""; return; }
    chain="$work/chain.pem"

    timeout 25 openssl s_client -connect "$BASE_HOST:443" -servername "$BASE_HOST" -showcerts \
        </dev/null 2>/dev/null \
        | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' > "$chain"

    if [ ! -s "$chain" ]; then
        rm -rf "$work"
        sec_skip "Could not reach $BASE_HOST:443 (no network, or the host is unreachable)."
        echo ""
        return
    fi

    # Split the leaf from the intermediates the server also sent.
    awk -v dir="$work" '
        BEGIN { n = 0 }
        /-----BEGIN CERTIFICATE-----/ { n++ }
        n == 1 { print > (dir "/leaf.pem"); next }
        { print > (dir "/rest.pem") }
    ' "$chain"
    [ -f "$work/rest.pem" ] || : > "$work/rest.pem"

    echo "    > Server sent $(grep -c 'BEGIN CERTIFICATE' "$chain") certificate(s)."

    # Mirrors what Dart does: -partial_chain because SecurityContext accepts a
    # non-self-signed anchor, and the system store is excluded because the app
    # uses withTrustedRoots: false. Without -no-CApath/-no-CAstore this check
    # would pass against any CA and prove nothing.
    local verify_out
    verify_out=$(openssl verify -partial_chain -no-CApath -no-CAstore \
        -CAfile "$CERT_PATH" -untrusted "$work/rest.pem" "$work/leaf.pem" 2>&1)

    if echo "$verify_out" | grep -q ': OK$'; then
        if pin_is_ca; then
            echo "    > The leaf chains up to the pinned CA."
        else
            local pinned live
            pinned=$(openssl x509 -in "$CERT_PATH" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)
            live=$(openssl x509 -in "$work/leaf.pem" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)
            echo "    > Pinned SHA-256: $pinned"
            echo "    > Server SHA-256: $live"
        fi
        rm -rf "$work"
        sec_pass "The server's certificate is accepted by the pin."
        echo ""
        return
    fi

    echo "$verify_out" | sed 's/^/    > /' | head -4
    echo "    > Pinning fails closed, so this means the app cannot reach the"
    echo "      server at all, not that it is merely less protected."
    rm -rf "$work"
    sec_fail "The server's certificate is NOT accepted by the pin."
    echo ""
}

function test_pin_rotation_risk() {
    sec_begin "Pin type and rotation headroom"
    cert_usable || {
        sec_skip "Certificate missing or not parseable; see the first check."
        echo ""
        return
    }

    local constraints count
    constraints=$(openssl x509 -in "$CERT_PATH" -noout -ext basicConstraints 2>/dev/null)
    count=$(grep -c 'BEGIN CERTIFICATE' "$CERT_PATH")

    if echo "$constraints" | grep -q 'CA:TRUE'; then
        sec_pass "An issuing CA is pinned, which survives leaf rotation."
        echo ""
        return
    fi

    echo "    > A leaf certificate is pinned (CA:FALSE), so every renewal breaks"
    echo "      older clients unless a replacement ships first."
    if [ "$count" -gt 1 ]; then
        echo "    > $count certificates are bundled, so a backup pin appears to be present."
        sec_pass "Leaf pinning with a backup pin present."
    else
        echo "    > Only one certificate is bundled, so there is no backup pin: the"
        echo "      day the server rotates, every existing install goes offline."
        sec_inconclusive "Leaf pinning with no backup pin. Acceptable only with a controlled rollout."
    fi
    echo ""
}

function test_user_ca_not_trusted() {
    sec_begin "Network security config does not trust user-installed CAs"

    if [ ! -f "$NSC_PATH" ]; then
        sec_fail "No network_security_config.xml found."
        echo ""
        return
    fi

    # Comments are stripped first: this file documents "Do NOT include
    # <certificates src="user" />" in a comment, and matching that text
    # produced a false VULNERABLE verdict. Then the debug-overrides block is
    # dropped, since trusting user CAs there is intentional and is stripped
    # from release APKs by the build system.
    local release_config
    release_config=$(sec_strip_xml_comments "$NSC_PATH" \
        | sed '/<debug-overrides>/,/<\/debug-overrides>/d')

    if echo "$release_config" | grep -q 'src="user"'; then
        sec_fail "Release configuration trusts user-installed CAs, the usual MITM vector."
        echo ""
        return
    fi

    if echo "$release_config" | grep -q 'cleartextTrafficPermitted="true"'; then
        sec_fail "Release configuration permits cleartext HTTP."
        echo ""
        return
    fi

    echo "    > Release config trusts only the system CA store."
    echo "    > Cleartext traffic is not permitted."
    sec_pass "Network security config is hardened for release."
    echo ""
}

function test_certificate_shipped_in_apk() {
    sec_begin "Pinned certificate is actually bundled in the APK"

    local apk
    apk=$(sec_find_apk) || { sec_skip "No built APK found; build one to verify the asset ships."; echo ""; return; }
    command -v unzip >/dev/null 2>&1 || { sec_skip "unzip not available."; echo ""; return; }

    echo "    > APK: $apk"
    local entry
    entry=$(unzip -l "$apk" 2>/dev/null | grep -i 'assets/.*certificates/' | head -3)

    if [ -z "$entry" ]; then
        sec_fail "No certificate asset inside the APK; pinning would fail at runtime."
        echo ""
        return
    fi

    echo "$entry" | sed 's/^/    > /'
    sec_pass "Certificate asset is bundled in the APK."
    echo ""
}


function test_no_silent_unpinned_fallback() {
    sec_begin "A failed pin must not fall back to an unpinned client"

    local src="$APP_DIR/lib/security/network/ssl_pinning.dart"
    if [ ! -f "$src" ]; then
        sec_skip "ssl_pinning.dart not found."
        echo ""
        return
    fi

    # Source-level regression guard. The dangerous refactor is returning null
    # from the error path: null is the signal for "pinning not requested", so
    # the caller keeps its default client, silently restoring system and user CA
    # trust. A missing certificate would then look like a working app rather
    # than a packaging mistake.
    local catch_body
    catch_body=$(awk '/} catch \(e\) \{/,/^  }/' "$src")

    if [ -z "$catch_body" ]; then
        echo "    > No error handling found around the certificate load."
        echo "    > A missing or malformed asset would throw during startup."
        sec_fail "Certificate loading is unguarded."
        echo ""
        return
    fi

    local problems=0

    if echo "$catch_body" | grep -qE 'return +null'; then
        echo "    > The error path returns null, which means \"use the default"
        echo "      client\" and silently disables pinning."
        problems=$((problems + 1))
    fi

    if ! echo "$catch_body" | grep -q '_refusingClient'; then
        echo "    > The error path does not return a connection-refusing client."
        problems=$((problems + 1))
    fi

    if ! echo "$catch_body" | grep -q 'sslPinningFailure'; then
        echo "    > The error path does not record the failure on AppSecurity,"
        echo "      so it would be invisible wherever debugPrint is silenced."
        problems=$((problems + 1))
    fi

    if [ "$problems" -eq 0 ]; then
        echo "    > Error path returns a refusing client and records the reason."
        echo "    > Verified behaviourally by test/security/ssl_pinning_test.dart."
        sec_pass "A failed pin fails closed instead of falling back."
    else
        sec_fail "$problems problem(s) in the pin failure path."
    fi
    echo ""
}

test_certificate_present
test_certificate_validity
test_certificate_matches_host
test_certificate_matches_server
test_pin_rotation_risk
test_user_ca_not_trusted
test_certificate_shipped_in_apk
test_no_silent_unpinned_fallback

sec_summary
