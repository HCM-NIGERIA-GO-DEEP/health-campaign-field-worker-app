#!/bin/bash

PACKAGE_NAME="com.digit.hcm"
OBSERVE_SECONDS=10

echo "==========================================================="
echo " Testing Root Detection Bypass Prevention Mitigation"
echo " Package: $PACKAGE_NAME"
echo "==========================================================="
echo ""
echo "[i] This test observes the app from outside, so it needs a build that"
echo "    leaves detection observable:"
echo ""
echo "      flutter build apk --release --dart-define=SECURITY_TEST_MODE=true"
echo ""
echo "    A normal build silences debugPrint and terminates the process on a"
echo "    confirmed threat. Both are correct for production, and both hide the"
echo "    evidence this script looks for."
echo ""

# Check ADB
if ! command -v adb &> /dev/null; then
    echo "[!] ADB could not be found. Please ensure Android platform-tools"
    echo "    are installed and adb is in your system PATH."
    exit 1
fi

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

TOTAL_TESTS=0
SUCCESS_COUNT=0
FAILURE_COUNT=0
SKIPPED_COUNT=0
INCONCLUSIVE_COUNT=0

# Populated by observe_launch()
THREAT_LOG=""
APP_EXITED=0
APP_STARTED=0

function app_pid() {
    local pid
    pid=$(adb shell pidof "$PACKAGE_NAME" 2>/dev/null | tr -d '\r\n')
    if [[ -z "$pid" ]]; then
        # pidof is missing on some older images
        pid=$(adb shell ps 2>/dev/null | grep -w "$PACKAGE_NAME" | head -1 | tr -d '\r\n')
    fi
    echo "$pid"
}

# Launches the app and watches both logcat and process liveness.
#
# Liveness matters: with the shipped response mode a detected threat calls
# exit(0), so the app disappearing is itself evidence that a check fired, even
# when the log was suppressed.
function observe_launch() {
    THREAT_LOG=""
    APP_EXITED=0
    APP_STARTED=0

    echo "    > Clear logcat and launch app..."
    adb logcat -c
    adb shell am force-stop "$PACKAGE_NAME" >/dev/null 2>&1
    adb shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

    echo "    > Watching for ${OBSERVE_SECONDS}s (logcat + process liveness)..."
    local i
    for ((i = 0; i < OBSERVE_SECONDS * 2; i++)); do
        if [[ -n "$(app_pid)" ]]; then
            APP_STARTED=1
        elif [[ $APP_STARTED -eq 1 ]]; then
            APP_EXITED=1
            break
        fi
        sleep 0.5
    done

    THREAT_LOG=$(adb logcat -d | grep -i "Security threat detected")
}

# Reports the outcome of an observation for a case where a threat is expected.
function report_expected_threat() {
    local label="$1"

    if [[ -n "$THREAT_LOG" ]]; then
        echo "    > Log output: $THREAT_LOG"
        echo "    Result : [SECURE] App detected and reported the threat ($label)."
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        return
    fi

    if [[ $APP_EXITED -eq 1 ]]; then
        echo "    > No threat logged, but the app process exited during the window."
        echo "    > That is the shipped enforcement path: a confirmed threat calls"
        echo "      exit(0), and log suppression hides the message."
        echo "    Result : [INCONCLUSIVE] Detection most likely fired. Rebuild with"
        echo "             --dart-define=SECURITY_TEST_MODE=true for a definitive result."
        INCONCLUSIVE_COUNT=$((INCONCLUSIVE_COUNT + 1))
        return
    fi

    if [[ $APP_STARTED -eq 0 ]]; then
        echo "    > The app never appeared in the process list."
        echo "    Result : [INCONCLUSIVE] App did not start; nothing was verified."
        INCONCLUSIVE_COUNT=$((INCONCLUSIVE_COUNT + 1))
        return
    fi

    echo "    > No security threat logged, and the app is still running."
    echo "    Result : [VULNERABLE] App failed to detect $label."
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
}

function test_hook_framework_detection() {
    echo "[*] Testing Hooking Framework Detection (Frida)"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    # The previous version wrote a pseudo frida-server to /data/local/tmp and
    # expected the app to notice. It cannot: /data/local/tmp is shell-owned and
    # SELinux denies app processes access to it on Android 10+, so
    # File("/data/local/tmp/frida-server").exists() is false inside the app no
    # matter what the file mode is. chmod does not help, because the denial is
    # SELinux rather than POSIX. That test could only ever report a false
    # negative, so it is not run.
    echo "    > Skipping the /data/local/tmp file-drop simulation: SELinux denies"
    echo "      app processes access to that directory on Android 10+, so the app"
    echo "      cannot see a planted file and the test can only report a false"
    echo "      negative."
    echo ""
    echo "    > To verify hook detection for real, run an actual frida-server on a"
    echo "      rooted device or emulator and attach to the app:"
    echo "          adb push frida-server /data/local/tmp/ && adb shell su -c \\"
    echo "            '/data/local/tmp/frida-server &'"
    echo "          frida -U -n $PACKAGE_NAME"
    echo "      then re-run the app and check logcat for 'Security threat detected'."
    echo "      The native check looks for gadget libraries and frida's default"
    echo "      ports (27042/27043), which a real server does expose."
    echo "    Result : [SKIPPED] Not verifiable without a running frida-server."
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    echo ""
}

function test_root_detection() {
    echo "[*] Testing Root Detection & Emulator Status..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local is_device_rooted
    local is_emulator
    is_device_rooted=$(adb shell "su -c 'echo root_test' 2>/dev/null" | tr -d '\r\n')
    is_emulator=$(adb shell getprop ro.kernel.qemu | tr -d '\r\n')

    # ro.kernel.qemu is unset on newer emulator images; fall back to the same
    # build properties the native check reads.
    if [[ "$is_emulator" != "1" ]]; then
        local fingerprint
        fingerprint=$(adb shell getprop ro.build.fingerprint | tr -d '\r\n')
        if [[ "$fingerprint" == generic* || "$fingerprint" == unknown* ]]; then
            is_emulator="1"
        fi
    fi

    local expected_label=""
    if [[ "$is_device_rooted" == "root_test" ]]; then
        echo "    > Device has root access."
        expected_label="a rooted device"
    elif [[ "$is_emulator" == "1" ]]; then
        echo "    > Device is an emulator."
        expected_label="an emulator"
    else
        echo "    > Device appears to be a physical non-rooted device."
    fi

    observe_launch

    if [[ -z "$expected_label" ]]; then
        # Nothing to detect, so silence is the correct outcome.
        if [[ -n "$THREAT_LOG" ]]; then
            echo "    > Log output: $THREAT_LOG"
            echo "    Result : [VULNERABLE] App reported a threat on a clean device"
            echo "             (false positive)."
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
        else
            echo "    > No security threat logged (expected on a clean device)."
            echo "    Result : [SECURE] App runs cleanly on a non-rooted device."
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
        echo ""
        return
    fi

    report_expected_threat "$expected_label"
    echo ""
}

test_hook_framework_detection
test_root_detection

echo "==========================================================="
echo " Testing Complete."
echo " Total Tests Run : $TOTAL_TESTS"
echo " Passed (Secure) : $SUCCESS_COUNT"
echo " Failed (Vuln)   : $FAILURE_COUNT"
echo " Inconclusive    : $INCONCLUSIVE_COUNT"
echo " Skipped         : $SKIPPED_COUNT"
echo "==========================================================="
