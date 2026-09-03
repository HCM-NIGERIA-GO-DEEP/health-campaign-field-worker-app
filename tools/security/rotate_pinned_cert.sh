#!/bin/bash
# Rotates the pinned trust anchor in assets/certificates/tls_cert.crt.
#
# The ROTATION note in that file used to be prose telling a maintainer to
# "replace this". This performs the replacement, and refuses to write a bundle
# that would not actually validate the live server, because pinning fails
# closed: a wrong anchor does not weaken the app, it takes it offline.
#
# WHEN TO RUN THIS
#
# Almost never. Pinning the issuer rather than the leaf means routine
# certificate renewal needs no app change at all. Run it only when one of these
# is true:
#
#   * test_ssl_pinning.sh fails "Live server chain validates against the pinned
#     certificate". The server now presents a chain the pin does not accept,
#     which normally means the CA changed. Use --add and the playbook below.
#   * test_ssl_pinning.sh reports the pinned anchor is near expiry (30-day
#     horizon; the current anchor runs to Mar 2036).
#   * A CA or certificate-provider migration is planned. Run it BEFORE the
#     server switches, with --add.
#   * BASE_URL moves to a different host or environment. Pass --host.
#
# Do NOT run it for:
#
#   * A leaf renewal. That is precisely the case pinning the issuer absorbs.
#   * A routine release.
#   * A corrupt tls_cert.crt whose anchor is still correct. Restore it with
#     `git checkout -- <path>`, which cannot change what is trusted; rotating
#     would silently re-pin to whatever the server happens to present today.
#
# Running it to LOOK is always safe: the default is a dry run, and it refuses
# to write an anchor that does not validate the live server. It also prints the
# live chain, so it doubles as a diagnostic.
#
# Usage:
#   ./rotate_pinned_cert.sh                      # dry run, intermediate anchor
#   ./rotate_pinned_cert.sh --anchor root        # dry run, root anchor
#   ./rotate_pinned_cert.sh --write              # write it
#   ./rotate_pinned_cert.sh --host other.example --anchor leaf --write
#
# Anchors:
#   intermediate  the CA that issued the leaf. Default. Survives leaf renewal.
#   root          the CA that issued the intermediate. Survives an intermediate
#                 change too, at the cost of trusting more of that CA's output.
#   leaf          the server certificate itself. Tightest, and expires soonest;
#                 every renewal takes existing installs offline.
#
# IMPORTANT: this edits a bundled asset, so it only affects builds made after
# it runs. There is no way to push a pin to an app that is already installed.
# Pinning fails closed, so if the server starts presenting a certificate no
# installed build trusts, those installs cannot reach the API at all.
#
# That is why the issuer is pinned rather than the leaf: routine leaf renewals
# need no app update. An app update is only required when the CA itself changes.
#
# For that case use the overlap playbook, with --add:
#
#   1. ./rotate_pinned_cert.sh --host <new-host-or-same> --anchor intermediate --add --write
#      (bundle now trusts the current CA *and* the incoming one)
#   2. release, and wait for field adoption
#   3. only then let the server switch to the new CA
#   4. later, rerun without --add to drop the superseded anchor
#
# Ordering matters: step 3 before step 2 takes every un-updated install offline.
#
# Two anchors from the SAME chain are redundant, since trust is the union and a
# root supersedes its own intermediate. Two anchors from DIFFERENT CAs are a
# genuine backup pin, and are what makes a migration survivable.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ANCHOR="intermediate"
WRITE=0
ADD=0
HOST=""

while [ $# -gt 0 ]; do
    case "$1" in
        --anchor) ANCHOR="$2"; shift 2 ;;
        --host)   HOST="$2"; shift 2 ;;
        --write)  WRITE=1; shift ;;
        --add)    ADD=1; shift ;;
        # Prints the whole header comment rather than a fixed line range: a
        # hard-coded range silently truncates the moment the header grows.
        -h|--help)
            awk 'NR == 1 { next }
                 /^#/ { sub(/^# ?/, ""); print; next }
                 { exit }' "$0"
            exit 0
            ;;
        *) echo "[!] Unknown argument: $1"; exit 1 ;;
    esac
done

case "$ANCHOR" in
    intermediate|root|leaf) ;;
    *) echo "[!] --anchor must be intermediate, root or leaf"; exit 1 ;;
esac

command -v openssl >/dev/null 2>&1 || { echo "[!] openssl is required."; exit 1; }

APP_DIR=$(sec_app_dir) || { echo "[!] Could not locate the app directory."; exit 1; }
CERT_PATH="$APP_DIR/assets/certificates/tls_cert.crt"

if [ -z "$HOST" ]; then
    HOST=$(sec_env_value BASE_URL | sed -E 's#^[a-z]+://##; s#/.*$##; s#:.*$##')
fi
[ -n "$HOST" ] || { echo "[!] No host given and BASE_URL could not be read."; exit 1; }

echo "==========================================================="
echo " Rotating the pinned trust anchor"
echo "==========================================================="
echo "  host   : $HOST"
echo "  anchor : $ANCHOR"
echo "  action : $([ $ADD -eq 1 ] && echo 'ADD to existing anchors (migration overlap)' || echo 'REPLACE existing anchor')"
echo "  target : $CERT_PATH"
echo "  mode   : $([ $WRITE -eq 1 ] && echo 'WRITE' || echo 'dry run')"
echo ""

WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT

echo "[*] Fetching the certificate chain from $HOST..."
timeout 30 openssl s_client -connect "$HOST:443" -servername "$HOST" -showcerts \
    </dev/null 2>/dev/null \
    | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' > "$WORK/chain.pem"

if [ ! -s "$WORK/chain.pem" ]; then
    echo "[!] Could not retrieve a chain from $HOST:443."
    exit 1
fi

# Split the chain into one file per certificate.
awk -v dir="$WORK" 'BEGIN { n = -1 }
    /-----BEGIN CERTIFICATE-----/ { n++ }
    { print > (dir "/cert" n ".pem") }
' "$WORK/chain.pem"

COUNT=$(grep -c 'BEGIN CERTIFICATE' "$WORK/chain.pem")
echo "    > $COUNT certificate(s) received"

function subject_of() { openssl x509 -in "$1" -noout -subject 2>/dev/null | sed 's/^subject=//'; }
function issuer_of()  { openssl x509 -in "$1" -noout -issuer  2>/dev/null | sed 's/^issuer=//'; }
function expiry_of()  { openssl x509 -in "$1" -noout -enddate 2>/dev/null | cut -d= -f2; }
function is_ca()      { openssl x509 -in "$1" -noout -ext basicConstraints 2>/dev/null | grep -q 'CA:TRUE'; }

LEAF="$WORK/cert0.pem"
echo ""
echo "[*] Chain:"
for f in "$WORK"/cert*.pem; do
    printf "    %-4s %s\n" "$(is_ca "$f" && echo 'CA' || echo 'leaf')" "$(subject_of "$f")"
    printf "         expires %s\n" "$(expiry_of "$f")"
done

# Resolve the requested anchor by walking issuer links rather than assuming
# chain order, which servers do not guarantee.
LEAF_ISSUER=$(issuer_of "$LEAF")
INTERMEDIATE=""
for f in "$WORK"/cert*.pem; do
    [ "$f" = "$LEAF" ] && continue
    if [ "$(subject_of "$f")" = "$LEAF_ISSUER" ] && is_ca "$f"; then
        INTERMEDIATE="$f"
        break
    fi
done

ROOT=""
if [ -n "$INTERMEDIATE" ]; then
    INT_ISSUER=$(issuer_of "$INTERMEDIATE")
    for f in "$WORK"/cert*.pem; do
        if [ "$(subject_of "$f")" = "$INT_ISSUER" ] && is_ca "$f"; then
            ROOT="$f"
            break
        fi
    done
fi

case "$ANCHOR" in
    leaf)         SELECTED="$LEAF" ;;
    intermediate) SELECTED="$INTERMEDIATE" ;;
    root)         SELECTED="$ROOT" ;;
esac

if [ -z "$SELECTED" ] || [ ! -f "$SELECTED" ]; then
    echo ""
    echo "[!] The server did not send a certificate matching --anchor $ANCHOR."
    if [ "$ANCHOR" = "root" ]; then
        echo "    Many servers omit the root. Use --anchor intermediate, or fetch"
        echo "    the root from the CA and pin it manually."
    fi
    exit 1
fi

echo ""
echo "[*] Selected anchor:"
echo "    subject : $(subject_of "$SELECTED")"
echo "    expires : $(expiry_of "$SELECTED")"

# The gate. Same semantics the app uses: -partial_chain because BoringSSL
# accepts a non-self-signed anchor, and the system store excluded to mirror
# withTrustedRoots: false. Without those flags this would pass against anything.
# Every certificate the server sent except the leaf, as chain-building material.
# Built by concatenating files, not by filtering lines: using the leaf as a
# grep pattern file strips the BEGIN/END markers out of every certificate and
# leaves the result unparseable.
: > "$WORK/untrusted.pem"
for f in "$WORK"/cert*.pem; do
    [ "$f" = "$LEAF" ] && continue
    cat "$f" >> "$WORK/untrusted.pem"
done

# Assemble the anchor set that will be written.
: > "$WORK/anchors.pem"
SELECTED_FP=$(openssl x509 -in "$SELECTED" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)
KEPT=0

if [ $ADD -eq 1 ] && [ -f "$CERT_PATH" ]; then
    # Carry over every anchor already pinned, so a build exists that trusts
    # both the outgoing and incoming CA during the migration window.
    sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$CERT_PATH" \
        > "$WORK/existing.pem" 2>/dev/null || : > "$WORK/existing.pem"
    if [ -s "$WORK/existing.pem" ]; then
        awk -v dir="$WORK" 'BEGIN { n = -1 }
            /-----BEGIN CERTIFICATE-----/ { n++ }
            { print > (dir "/old" n ".pem") }
        ' "$WORK/existing.pem"
        for f in "$WORK"/old*.pem; do
            [ -f "$f" ] || continue
            local_fp=$(openssl x509 -in "$f" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)
            if [ -z "$local_fp" ]; then
                echo "    > skipping an unparseable certificate in the current file"
                continue
            fi
            if [ "$local_fp" = "$SELECTED_FP" ]; then
                continue    # already pinned; the append below covers it
            fi
            cat "$f" >> "$WORK/anchors.pem"
            KEPT=$((KEPT + 1))
            echo "    > keeping existing anchor: $(subject_of "$f")"
        done
    fi
fi

cat "$SELECTED" >> "$WORK/anchors.pem"
ANCHOR_COUNT=$(grep -c 'BEGIN CERTIFICATE' "$WORK/anchors.pem")

echo ""
echo "[*] Verifying the live leaf against the selected anchor..."
# openssl errors on an empty -untrusted file, which is the normal case when the
# leaf itself is the anchor.
if [ -s "$WORK/untrusted.pem" ]; then
    VERIFY=$(openssl verify -partial_chain -no-CApath -no-CAstore \
        -CAfile "$WORK/anchors.pem" -untrusted "$WORK/untrusted.pem" "$LEAF" 2>&1)
else
    VERIFY=$(openssl verify -partial_chain -no-CApath -no-CAstore \
        -CAfile "$WORK/anchors.pem" "$LEAF" 2>&1)
fi

if ! echo "$VERIFY" | grep -q ': OK$'; then
    echo "$VERIFY" | sed 's/^/    /'
    echo ""
    echo "[!] Refusing to write: this anchor does not validate the live server."
    echo "    Pinning fails closed, so shipping it would take the app offline."
    exit 1
fi
echo "    > OK: the leaf chains to this anchor with the app's own settings."

CURRENT_SUBJECT="(none)"
if [ -f "$CERT_PATH" ]; then
    CURRENT_SUBJECT=$(subject_of "$CERT_PATH")
    # An unreadable current pin is worth naming rather than printing blank: it
    # means the shipped asset is corrupt, which is its own incident.
    [ -z "$CURRENT_SUBJECT" ] && CURRENT_SUBJECT="(present but NOT PARSEABLE)"
fi
echo ""
echo "[*] Change:"
echo "    from : $CURRENT_SUBJECT"
echo "    to   : $(subject_of "$SELECTED")"

# Build the replacement, header regenerated from the certificate itself so it
# cannot drift from what is pinned.
{
    echo "# Pinned trust anchor for SSL pinning (see lib/security/network/ssl_pinning.dart)."
    echo "#"
    echo "# Generated by tools/security/rotate_pinned_cert.sh on $(date '+%d %b %Y')."
    echo "# Do not hand-edit: rerun that script so the header cannot drift from"
    echo "# the certificate below."
    echo "#"
    echo "#   host    : $HOST"
    echo "#   anchors : $ANCHOR_COUNT"
    echo "#"
    # Split prefix must not glob-match the bundle itself: "anchors.pem" starts
    # with "anchor", so an anchor*.pem loop picked up the bundle too and listed
    # its first certificate a second time.
    awk -v dir="$WORK" 'BEGIN { n = -1 }
        /-----BEGIN CERTIFICATE-----/ { n++ }
        { print > (dir "/pin" n ".pem") }
    ' "$WORK/anchors.pem"
    for f in "$WORK"/pin*.pem; do
        echo "#   - $(subject_of "$f")"
        echo "#     expires $(expiry_of "$f")"
    done
    echo "#"
    if [ "$ANCHOR_COUNT" -gt 1 ]; then
        echo "# MIGRATION BUNDLE. More than one anchor is trusted so that installed"
        echo "# builds keep working while the server moves between CAs. Drop the"
        echo "# superseded anchor once the field has adopted the new build: rerun"
        echo "# this script without --add."
        echo "#"
    fi
    if [ "$ANCHOR" = "leaf" ]; then
        echo "# WARNING: pinning the leaf means every certificate renewal takes every"
        echo "# installed build offline, because pinning fails closed and field devices"
        echo "# do not update on demand. Prefer --anchor intermediate unless a rollout"
        echo "# is coordinated with the server change."
    else
        echo "# The issuer is pinned rather than the server leaf, so leaf renewals do not"
        echo "# take installed builds offline. Trust stays narrow: this one CA, not the"
        echo "# system or user store, so an attacker-installed device CA is still"
        echo "# refused, which is the threat pinning exists to stop. Hostname"
        echo "# verification still applies to the leaf, so certificates for other hosts"
        echo "# are not accepted."
    fi
    echo "#"
    echo "# ROTATION: rerun ./tools/security/rotate_pinned_cert.sh --write before the"
    echo "# expiry above, or sooner if the CA starts issuing from a different"
    echo "# intermediate. tools/security/test_ssl_pinning.sh checks the expiry horizon"
    echo "# and that the live chain still validates against whatever is pinned here."
    echo "#"
    echo "# Only one anchor is pinned. Bundling several is not a backup pin: trust is"
    echo "# the union of the anchors, so intermediate+root behaves like root alone."
    echo "# To widen deliberately, rerun with --anchor root."
    echo "#"
    cat "$SELECTED"
} > "$WORK/new_bundle.crt"

if [ $WRITE -eq 0 ]; then
    echo ""
    echo "[*] Dry run. Proposed file:"
    echo "-----------------------------------------------------------"
    sed -n '1,24p' "$WORK/new_bundle.crt"
    echo "-----------------------------------------------------------"
    echo ""
    echo "    Rerun with --write to apply."
    exit 0
fi

cp "$WORK/new_bundle.crt" "$CERT_PATH"
echo ""
echo "[*] Written to $CERT_PATH"
echo ""
echo "    Next steps:"
echo "      1. ./tools/security/test_ssl_pinning.sh"
echo "      2. rebuild the APK so the new asset ships"
echo "      3. release it, and wait for field adoption"
echo "      4. only then let the server present the new certificate"
echo ""
echo "    Steps 3 and 4 are ordered on purpose. Pinning fails closed, and an"
echo "    installed build cannot be given a new pin, so switching the server"
echo "    first takes every un-updated install offline."
if [ "$ANCHOR_COUNT" -gt 1 ]; then
    echo "      5. after adoption, rerun without --add to drop the old anchor"
fi
