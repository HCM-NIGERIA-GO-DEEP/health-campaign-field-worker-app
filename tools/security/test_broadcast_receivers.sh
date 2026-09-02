#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# Configuration
PACKAGE_NAME="com.digit.hcm"
WATCHDOG_RECEIVER="id.flutter.flutter_background_service.WatchdogReceiver"
BOOT_RECEIVER="id.flutter.flutter_background_service.BootReceiver"

# Optional: path to the built APK for binary manifest verification.
# If set, aapt2 is used as a secondary check to confirm exported=false
# and eliminate ADB shell false positives.
# Usage: APK_PATH=/path/to/app.apk ./test_broadcast_receivers.sh
APK_PATH="${APK_PATH:-}"
# Path to aapt2 binary (auto-detected from ANDROID_HOME if not set)
AAPT2_PATH="${AAPT2_PATH:-}"

echo "==========================================================="
echo " Testing Insecure Broadcast Receiver Mitigations"
echo " Package: $PACKAGE_NAME"
echo "==========================================================="
echo ""

# Check if ADB is available
if ! command -v adb &> /dev/null; then
    echo "[!] ADB could not be found. Please ensure Android platform-tools"
    echo "    are installed and adb is in your system PATH."
    exit 1
fi

# Check if an emulator/device is connected
if ! adb get-state 1>/dev/null 2>&1; then
    echo "[!] No Android device/emulator found. Please connect a device or"
    echo "    start an emulator."
    exit 1
fi

# Check if the app is installed
if ! adb shell pm list packages | grep -q "^package:${PACKAGE_NAME}$"; then
    echo "[!] App $PACKAGE_NAME is not installed on the connected device."
    echo "    Please install the app on the device and try again."
    exit 1
fi

# Auto-detect aapt2 from ANDROID_HOME or common SDK paths
if [ -z "$AAPT2_PATH" ]; then
    SDK_ROOTS=("$ANDROID_HOME" "$HOME/Library/Android/sdk" "$HOME/Android/Sdk" \
               "$LOCALAPPDATA/Android/Sdk" "/usr/local/lib/android/sdk")
    for sdk in "${SDK_ROOTS[@]}"; do
        if [ -d "$sdk/build-tools" ]; then
            AAPT2_PATH=$(find "$sdk/build-tools" -name "aapt2" -o -name "aapt2.exe" 2>/dev/null \
                         | sort -rV | head -1)
            [ -n "$AAPT2_PATH" ] && break
        fi
    done
fi

# Verify aapt2 manifest: returns 0 (exported=false/not found) or 1 (exported=true)
# Usage: manifest_exported_check <receiver_class>
function manifest_exported_check() {
    local receiver_class=$1
    [ -z "$APK_PATH" ] && return 2   # no APK path → skip
    [ -z "$AAPT2_PATH" ] && return 2 # no aapt2    → skip

    local xml
    xml=$("$AAPT2_PATH" dump xmltree "$APK_PATH" --file AndroidManifest.xml 2>/dev/null)
    if [ -z "$xml" ]; then return 2; fi

    # Extract the block for this receiver and check its exported attribute.
    # Strategy: find the line with the receiver name, then scan forward until
    # the next 'E: receiver' opening tag for the exported= attribute.
    local in_receiver=0
    local result=2  # 2 = not found

    while IFS= read -r line; do
        if echo "$line" | grep -q "\"${receiver_class}\""; then
            in_receiver=1
            continue
        fi
        if [ "$in_receiver" -eq 1 ]; then
            # Stop at next receiver/service/activity element
            if echo "$line" | grep -qP "^\s+E: (receiver|service|activity|application)\b"; then
                break
            fi
            if echo "$line" | grep -q "android:exported"; then
                if echo "$line" | grep -q "=true"; then
                    result=1  # exported=true → vulnerable
                else
                    result=0  # exported=false → secure
                fi
                break
            fi
        fi
    done <<< "$xml"

    return $result
}

TOTAL_TESTS=0
SUCCESS_COUNT=0
FAILURE_COUNT=0

function test_receiver() {
    local receiver=$1
    local action=$2
    local action_param=""
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ ! -z "$action" ]; then
        action_param="-a $action"
    fi

    echo "[*] Testing ${receiver}..."
    local cmd="adb shell am broadcast $action_param -n $PACKAGE_NAME/$receiver"
    echo "    Command: $cmd"
    
    # Run the command and capture output.
    # Note: 'am broadcast' can write to stderr if there's a security exception.
    local output
    output=$($cmd 2>&1)
    
    # Format the output slightly for readability
    echo "$output" | while read -r line; do
        echo "    > $line"
    done

    if echo "$output" | grep -qi "Permission Denial"; then
        echo "    Result : [SECURE] Access Denied. The receiver is not exported or requires permissions."
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    elif echo "$output" | grep -qi "Broadcast completed"; then
        # am broadcast -n from ADB shell (uid=2000) can bypass android:exported=false
        # because the shell user has elevated privileges.  Perform a secondary
        # check against the binary APK manifest via aapt2 to eliminate this
        # false positive before declaring a real vulnerability.
        manifest_exported_check "$receiver"
        local manifest_status=$?

        if [ "$manifest_status" -eq 0 ]; then
            echo "    Note   : Broadcast succeeded due to ADB shell privilege bypass (uid=2000)."
            echo "             Binary manifest verification confirms android:exported=false."
            echo "             Real apps (uid>=10000) cannot send this broadcast."
            echo "    Result : [SECURE] Manifest confirms exported=false. ADB false positive."
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        elif [ "$manifest_status" -eq 1 ]; then
            echo "    Result : [VULNERABLE] Broadcast completed AND manifest confirms exported=true!"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
        else
            echo "    Note   : Could not perform secondary manifest verification"
            echo "             (set APK_PATH and ensure aapt2 is available for confirmation)."
            echo "    Result : [LIKELY VULNERABLE] Broadcast completed. Verify exported attribute manually."
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
        fi
    else
        echo "    Result : [UNKNOWN] Could not determine status. Please review the output above."
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
    echo ""
}

# Test both broadcast receivers
APK_PATH="${APK_PATH:-../../apps/health_campaign_field_worker_app/build/app/outputs/flutter-apk/app-release.apk}"

# ---------------------------------------------------------------------------
# Full component sweep. The tests above probe two known receivers by name; this
# enumerates every component in the merged manifest, so a newly added or
# plugin-contributed exported component cannot slip through unnoticed.
# ---------------------------------------------------------------------------

function test_all_exported_components() {
    sec_begin "Sweeping every component in the merged manifest for unguarded exports"

    local apk aapt2
    apk=$(sec_find_apk) || { sec_skip "No built APK found; set APK_PATH or build one."; echo ""; return; }
    aapt2=$(sec_find_aapt2) || { sec_skip "aapt2 not found; set ANDROID_HOME or AAPT2_PATH."; echo ""; return; }

    echo "    > APK: $apk"

    local xml
    xml=$("$aapt2" dump xmltree "$apk" --file AndroidManifest.xml 2>/dev/null)
    if [ -z "$xml" ]; then
        sec_skip "aapt2 could not read the manifest."
        echo ""
        return
    fi

    # Walk the tree keeping the current element, and record name/exported/
    # permission per component. aapt2 renders true as 0xffffffff.
    local findings
    # aapt2 prints attributes with the full namespace URI and renders booleans
    # as true/false (older builds use 0xffffffff), so both forms are matched.
    findings=$(echo "$xml" | awk '
        function flush() {
            if (elem != "" && exported == 1 && perm == 0) print elem " " name
            elem = ""
        }
        /^[ \t]*E: (activity|activity-alias|service|receiver|provider) / {
            flush(); elem = $2; name = "?"; exported = 0; perm = 0; next
        }
        /^[ \t]*E: / { flush(); next }
        elem != "" && /:name\(0x01010003\)=/ {
            if (match($0, /"[^"]+"/)) name = substr($0, RSTART + 1, RLENGTH - 2)
        }
        elem != "" && /:exported\(0x01010010\)=/ {
            exported = ($0 ~ /=true/ || $0 ~ /0xffffffff/) ? 1 : 0
        }
        elem != "" && /:permission\(0x01010006\)=/ { perm = 1 }
        END { flush() }
    ')

    # The launcher activity is required to be exported; everything else is not.
    local unexpected
    unexpected=$(echo "$findings" | grep -v 'LauncherActivity' | grep -v '^$')

    if [ -z "$unexpected" ]; then
        echo "    > Exported without a permission guard: only the launcher activity."
        sec_pass "No unexpected unguarded exported components."
        echo ""
        return
    fi

    echo "    > Exported with no permission guard:"
    echo "$unexpected" | sed 's/^/      - /'
    echo "    > Each of these is reachable from any other app on the device."
    echo "      Add android:exported=\"false\", or guard it with a signature-level"
    echo "      permission if it must stay reachable."
    sec_fail "$(echo "$unexpected" | wc -l | tr -d ' ') unguarded exported component(s) found."
    echo ""
}

function test_exported_providers() {
    sec_begin "Testing content providers for unguarded export and URI grants"

    local apk aapt2
    apk=$(sec_find_apk) || { sec_skip "No built APK found."; echo ""; return; }
    aapt2=$(sec_find_aapt2) || { sec_skip "aapt2 not found."; echo ""; return; }

    local xml
    xml=$("$aapt2" dump xmltree "$apk" --file AndroidManifest.xml 2>/dev/null)

    local providers
    providers=$(echo "$xml" | awk '
        function flush() {
            if (inp && exported == 1) print name (grants ? " [grantUriPermissions]" : "")
            inp = 0
        }
        /^[ \t]*E: provider / { flush(); inp = 1; name = "?"; exported = 0; grants = 0; next }
        /^[ \t]*E: / { next }
        inp && /:name\(0x01010003\)=/ {
            if (match($0, /"[^"]+"/)) name = substr($0, RSTART + 1, RLENGTH - 2)
        }
        inp && /:exported\(0x01010010\)=/ { exported = ($0 ~ /=true/ || $0 ~ /0xffffffff/) ? 1 : 0 }
        inp && /:grantUriPermissions\(/ { grants = ($0 ~ /=true/ || $0 ~ /0xffffffff/) ? 1 : 0 }
        END { flush() }
    ')

    if [ -z "$providers" ]; then
        echo "    > No exported content providers."
        sec_pass "No exported content providers."
    else
        echo "$providers" | sed 's/^/      - /'
        echo "    > FileProvider-style components are normally exported=false with"
        echo "      grantUriPermissions; anything else exported is worth reviewing."
        sec_inconclusive "Exported providers found; confirm each is intentional."
    fi
    echo ""
}

function test_runtime_registered_receivers() {
    sec_begin "Testing receivers registered at runtime"

    sec_device_ready || { sec_skip "No device connected."; echo ""; return; }

    # Runtime receivers never appear in the manifest, so a manifest-only sweep
    # cannot see them. On Android 13+ they must declare an export flag.
    local dump
    dump=$(adb shell dumpsys activity broadcasts 2>/dev/null | grep -A3 "$PACKAGE_NAME" | head -40)

    if [ -z "$dump" ]; then
        sec_skip "No broadcast state reported for $PACKAGE_NAME."
        echo ""
        return
    fi

    echo "    > Registered receiver entries referencing the package:"
    echo "$dump" | grep -oE 'Receiver[^ ]*|filter=[^ ]*|act=[^ ]*' | sort -u | head -10 | sed 's/^/      /'
    echo "    > MainActivity registers its location receiver with"
    echo "      RECEIVER_NOT_EXPORTED, which cannot be confirmed from dumpsys."
    sec_inconclusive "Runtime receivers listed for manual review."
    echo ""
}

test_receiver "$WATCHDOG_RECEIVER" ""
test_receiver "$BOOT_RECEIVER" "android.intent.action.BOOT_COMPLETED"

test_all_exported_components
test_exported_providers
test_runtime_registered_receivers

sec_summary
