#!/bin/bash
# Shared helpers for tools/security/*.sh. Sourced, never executed directly.
#
# Guiding rule: a check that cannot run must report SKIPPED, never SECURE and
# never VULNERABLE. Earlier versions of these scripts reported VULNERABLE for
# conditions that were impossible to observe, which is worse than reporting
# nothing because it buries the real findings.

# Counters. Initialised only if the calling script has not already done so.
: "${TOTAL_TESTS:=0}"
: "${SUCCESS_COUNT:=0}"
: "${FAILURE_COUNT:=0}"
: "${SKIPPED_COUNT:=0}"
: "${INCONCLUSIVE_COUNT:=0}"

sec_begin() {
    echo "[*] $1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

sec_pass() {
    echo "    Result : [SECURE] $1"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
}

sec_fail() {
    echo "    Result : [VULNERABLE] $1"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
}

sec_skip() {
    echo "    Result : [SKIPPED] $1"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
}

sec_inconclusive() {
    echo "    Result : [INCONCLUSIVE] $1"
    INCONCLUSIVE_COUNT=$((INCONCLUSIVE_COUNT + 1))
}

sec_summary() {
    echo "==========================================================="
    echo " Testing Complete."
    echo " Total Tests Run : $TOTAL_TESTS"
    echo " Passed (Secure) : $SUCCESS_COUNT"
    echo " Failed (Vuln)   : $FAILURE_COUNT"
    echo " Inconclusive    : $INCONCLUSIVE_COUNT"
    echo " Skipped         : $SKIPPED_COUNT"
    echo "==========================================================="
}

# Repository root, found by walking up to melos.yaml. Lets these scripts run
# from anywhere rather than only from tools/security.
sec_repo_root() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/melos.yaml" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

sec_app_dir() {
    local root
    root=$(sec_repo_root) || return 1
    echo "$root/apps/health_campaign_field_worker_app"
}

# Release APK, honouring APK_PATH if the caller set it.
sec_find_apk() {
    if [ -n "$APK_PATH" ] && [ -f "$APK_PATH" ]; then
        echo "$APK_PATH"
        return 0
    fi
    local app
    app=$(sec_app_dir) || return 1
    local candidate
    for candidate in \
        "$app/build/app/outputs/flutter-apk/app-release.apk" \
        "$app/build/app/outputs/apk/release/app-release.apk" \
        "$app/build/app/outputs/flutter-apk/app-debug.apk"; do
        [ -f "$candidate" ] && { echo "$candidate"; return 0; }
    done
    return 1
}

sec_find_aapt2() {
    if [ -n "$AAPT2_PATH" ] && [ -x "$AAPT2_PATH" ]; then
        echo "$AAPT2_PATH"
        return 0
    fi
    if command -v aapt2 >/dev/null 2>&1; then
        command -v aapt2
        return 0
    fi
    local sdk
    for sdk in "$ANDROID_HOME" "$ANDROID_SDK_ROOT" "$HOME/Android/Sdk" "$HOME/Library/Android/sdk"; do
        [ -z "$sdk" ] && continue
        [ -d "$sdk/build-tools" ] || continue
        local found
        found=$(find "$sdk/build-tools" -name 'aapt2' -type f 2>/dev/null | sort -r | head -1)
        [ -n "$found" ] && { echo "$found"; return 0; }
    done
    return 1
}

sec_device_ready() {
    command -v adb >/dev/null 2>&1 || return 1
    adb get-state >/dev/null 2>&1 || return 1
    return 0
}

# Reads a key out of the app .env, stripping surrounding quotes.
sec_env_value() {
    local key="$1"
    local app
    app=$(sec_app_dir) || return 1
    [ -f "$app/.env" ] || return 1
    grep -E "^${key}=" "$app/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"'' | tr -d '\r'
}

# Strips XML comments, including multi-line ones, so a grep for a dangerous
# attribute cannot match a comment that documents *not* using it. The
# network_security_config carries exactly such a comment, and matching it
# produced a false VULNERABLE verdict.
sec_strip_xml_comments() {
    awk '
    BEGIN { inc = 0 }
    {
        line = $0
        out = ""
        while (length(line) > 0) {
            if (inc) {
                p = index(line, "-->")
                if (p == 0) { line = "" }
                else { line = substr(line, p + 3); inc = 0 }
            } else {
                p = index(line, "<!--")
                if (p == 0) { out = out line; line = "" }
                else { out = out substr(line, 1, p - 1); line = substr(line, p + 4); inc = 1 }
            }
        }
        print out
    }' "$1"
}

# Warns when the APK predates the sources, so a finding is not misattributed to
# code that was never in the artifact under test.
sec_apk_is_stale() {
    local apk="$1"
    local app
    app=$(sec_app_dir) || return 1
    local newer
    newer=$(find "$app/lib" "$app/android" -type f -newer "$apk" 2>/dev/null | wc -l)
    echo "$newer"
    [ "$newer" -gt 0 ]
}
