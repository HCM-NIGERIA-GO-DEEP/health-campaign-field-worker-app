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
    sec_begin "Pinned certificate is currently valid"
    [ -f "$CERT_PATH" ] || { sec_skip "No certificate to check."; echo ""; return; }

    local not_after
    not_after=$(openssl x509 -in "$CERT_PATH" -noout -enddate 2>/dev/null | cut -d= -f2)
    echo "    > Expires: $not_after"

    if ! openssl x509 -in "$CERT_PATH" -noout -checkend 0 >/dev/null 2>&1; then
        sec_fail "Certificate has already expired. Any build shipping it cannot reach the server."
        echo ""
        return
    fi

    local horizon=$((EXPIRY_WARN_DAYS * 86400))
    if ! openssl x509 -in "$CERT_PATH" -noout -checkend "$horizon" >/dev/null 2>&1; then
        echo "    > Expires within $EXPIRY_WARN_DAYS days."
        echo "    > Pinning fails closed, so a new certificate must be shipped and"
        echo "      adopted by clients BEFORE the server rotates."
        sec_inconclusive "Certificate is valid now but expires soon; plan the rotation."
        echo ""
        return
    fi

    sec_pass "Certificate is valid and not expiring within $EXPIRY_WARN_DAYS days."
    echo ""
}

function test_certificate_matches_host() {
    sec_begin "Pinned certificate covers the configured BASE_URL host"
    [ -f "$CERT_PATH" ] || { sec_skip "No certificate to check."; echo ""; return; }

    if [ -z "$BASE_HOST" ]; then
        sec_skip "Could not read BASE_URL from the app .env."
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
    sec_begin "Pinned certificate matches what the server actually presents"
    [ -f "$CERT_PATH" ] || { sec_skip "No certificate to check."; echo ""; return; }

    if [ -z "$BASE_HOST" ]; then
        sec_skip "Could not read BASE_URL from the app .env."
        echo ""
        return
    fi

    local live
    live=$(timeout 25 openssl s_client -connect "$BASE_HOST:443" -servername "$BASE_HOST" \
            </dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
            | cut -d= -f2)

    if [ -z "$live" ]; then
        sec_skip "Could not reach $BASE_HOST:443 (no network, or the host is unreachable)."
        echo ""
        return
    fi

    local pinned
    pinned=$(openssl x509 -in "$CERT_PATH" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)

    echo "    > Pinned SHA-256: $pinned"
    echo "    > Server SHA-256: $live"

    if [ "$pinned" = "$live" ]; then
        sec_pass "Pinned certificate is the certificate the server presents."
    else
        sec_fail "Pinned certificate does NOT match the server. Requests will fail once pinning is on."
    fi
    echo ""
}

function test_pin_rotation_risk() {
    sec_begin "Pin type and rotation headroom"
    [ -f "$CERT_PATH" ] || { sec_skip "No certificate to check."; echo ""; return; }

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

test_certificate_present
test_certificate_validity
test_certificate_matches_host
test_certificate_matches_server
test_pin_rotation_risk
test_user_ca_not_trusted
test_certificate_shipped_in_apk

sec_summary
