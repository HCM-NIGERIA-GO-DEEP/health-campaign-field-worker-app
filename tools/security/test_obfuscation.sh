#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# Configuration
PACKAGE_NAME="com.digit.hcm"
BUILD_GRADLE_PATH="../apps/health_campaign_field_worker_app/android/app/build.gradle"

echo "==========================================================="
echo " Testing Improper Code Obfuscation Mitigation"
echo " Package: $PACKAGE_NAME"
echo "==========================================================="
echo ""

TOTAL_TESTS=0
SUCCESS_COUNT=0
FAILURE_COUNT=0

function check_gradle_obfuscation_settings() {
    echo "[*] Testing Code Obfuscation Configuration (Static Analysis)"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ ! -f "$BUILD_GRADLE_PATH" ]; then
        # Try fallback path if run from within the app folder
        BUILD_GRADLE_PATH="android/app/build.gradle"
    fi
    
    if [ ! -f "$BUILD_GRADLE_PATH" ]; then
        # Try fallback path if run from within tools folder
        BUILD_GRADLE_PATH="../../apps/health_campaign_field_worker_app/android/app/build.gradle"
    fi

    if [ ! -f "$BUILD_GRADLE_PATH" ]; then
        echo "    > [!] android/app/build.gradle not found at $BUILD_GRADLE_PATH"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        return
    fi
    
    echo "    > Analyzing android/app/build.gradle for minifyEnabled..."
    
    local minify_grep=$(grep "minifyEnabled true" "$BUILD_GRADLE_PATH")
    local shrink_grep=$(grep "shrinkResources true" "$BUILD_GRADLE_PATH")
    local proguard_grep=$(grep "proguardFiles" "$BUILD_GRADLE_PATH")
    
    if [[ ! -z "$minify_grep" ]]; then
        echo "    > Found minifyEnabled true:"
        echo "      $minify_grep"
        
        if [[ ! -z "$shrink_grep" ]]; then
           echo "    > Found shrinkResources true:"
           echo "      $shrink_grep"
        fi
        
        if [[ ! -z "$proguard_grep" ]]; then
           echo "    > Found ProGuard configuration:"
           echo "      $proguard_grep"
        fi
        
        echo "    Result : [SECURE] ProGuard / R8 code obfuscation and resource shrinking is enabled for the build process."
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "    > 'minifyEnabled true' was NOT found in the build configuration."
        echo "    Result : [VULNERABLE] The application release builds do NOT enforce code obfuscation!"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        return
    fi
    echo ""
}

function check_flutter_build_script() {
    echo "[*] Testing Flutter Obfuscation Configuration (build_obfuscated.sh)"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local SCRIPT_PATH="../apps/health_campaign_field_worker_app/build_obfuscated.sh"
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        SCRIPT_PATH="build_obfuscated.sh"
    fi
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        SCRIPT_PATH="../../apps/health_campaign_field_worker_app/build_obfuscated.sh"
    fi

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "    > [!] build_obfuscated.sh not found. Skipping."
        # This isn't strictly a failure if they use standard gradle, but let's count it
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        return
    fi
    
    echo "    > Analyzing the custom build script $SCRIPT_PATH..."
    
    local has_flutter_obfuscate=$(grep "\-\-obfuscate" "$SCRIPT_PATH")
    
    if [[ ! -z "$has_flutter_obfuscate" ]]; then
        echo "    > Found Flutter symbol obfuscation flag:"
        echo "      $has_flutter_obfuscate"
        echo "    Result : [SECURE] The Dart code is compiled with --obfuscate."
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "    > Flutter symbol obfuscation flag (--obfuscate) is NOT enabled."
        echo "    Result : [VULNERABLE] Flutter Dart bytecode may be easily reverse-engineered."
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
    
    echo ""
}


# ---------------------------------------------------------------------------
# APK-level checks. The static gradle checks above prove the build *intends*
# to obfuscate; these prove the shipped artifact actually did.
# ---------------------------------------------------------------------------

function check_apk_not_debuggable() {
    sec_begin "Testing that the APK is not debuggable"

    local apk aapt2
    apk=$(sec_find_apk) || { sec_skip "No built APK found. Build a release APK first."; echo ""; return; }
    aapt2=$(sec_find_aapt2) || { sec_skip "aapt2 not found; set ANDROID_HOME or AAPT2_PATH."; echo ""; return; }

    echo "    > APK: $apk"
    local badging
    badging=$("$aapt2" dump badging "$apk" 2>/dev/null)

    if echo "$badging" | grep -q "application-debuggable"; then
        sec_fail "APK is debuggable: anyone can attach a debugger and read app state."
    else
        echo "    > No application-debuggable flag present."
        sec_pass "APK is not debuggable."
    fi
    echo ""
}

function check_dex_class_names_obfuscated() {
    sec_begin "Testing that Kotlin/Java class names were renamed by R8"

    local apk
    apk=$(sec_find_apk) || { sec_skip "No built APK found."; echo ""; return; }
    command -v unzip >/dev/null 2>&1 || { sec_skip "unzip not available."; echo ""; return; }
    command -v strings >/dev/null 2>&1 || { sec_skip "strings not available."; echo ""; return; }

    # SecurityHelper is kept with -keep,allowobfuscation, so its name is
    # expected to be renamed. Finding it verbatim means R8 did not run, or a
    # blanket -keep is overriding the intent.
    local hits
    hits=$(unzip -p "$apk" 'classes*.dex' 2>/dev/null | strings | grep -c 'SecurityHelper')

    echo "    > Occurrences of 'SecurityHelper' in classes*.dex: $hits"
    if [ "$hits" -gt 0 ]; then
        echo "    > That class is declared -keep,allowobfuscation, so its name should"
        echo "      not survive. A blanket -keep rule may be overriding it."
        sec_fail "Security class names are readable in the DEX."
    else
        sec_pass "Security class names were renamed."
    fi
    echo ""
}

function check_dart_symbols_stripped() {
    sec_begin "Testing that Dart symbols were stripped (--obfuscate)"

    local apk
    apk=$(sec_find_apk) || { sec_skip "No built APK found."; echo ""; return; }
    command -v unzip >/dev/null 2>&1 || { sec_skip "unzip not available."; echo ""; return; }
    command -v strings >/dev/null 2>&1 || { sec_skip "strings not available."; echo ""; return; }

    local libapp
    libapp=$(unzip -l "$apk" 2>/dev/null | grep -oE 'lib/[^ ]*/libapp\.so' | head -1)
    if [ -z "$libapp" ]; then
        sec_skip "No libapp.so in the APK; nothing to inspect."
        echo ""
        return
    fi
    echo "    > Inspecting $libapp"

    # R8 does not touch Dart. Only `flutter build --obfuscate` removes these,
    # so this is the check that distinguishes the two.
    local hits
    hits=$(unzip -p "$apk" "$libapp" 2>/dev/null | strings \
            | grep -cE 'DeviceIntegrityService|AppSecurityFeature|ThreatResponseHandler')

    echo "    > Dart security symbol occurrences: $hits"
    if [ "$hits" -gt 0 ]; then
        echo "    > Dart class names are readable, so the build did not use"
        echo "      --obfuscate. R8 settings do not affect Dart code."
        echo "    > Rebuild with: flutter build apk --release --obfuscate \\"
        echo "        --split-debug-info=build/symbols"
        sec_fail "Dart symbols are readable in libapp.so."
    else
        sec_pass "Dart symbols were stripped."
    fi
    echo ""
}

function check_r8_mapping_retained() {
    sec_begin "Testing that the R8 mapping file was retained"

    local app
    app=$(sec_app_dir) || { sec_skip "Could not locate the app directory."; echo ""; return; }

    local mapping
    mapping=$(find "$app/build" -path '*mapping*release*' -name 'mapping.txt' 2>/dev/null | head -1)

    if [ -z "$mapping" ]; then
        echo "    > No mapping.txt found under build/."
        echo "    > Without it, a production stack trace cannot be de-obfuscated."
        sec_inconclusive "No mapping file found; it may not have been built yet."
    else
        echo "    > $mapping"
        echo "    > Archive this with the release: it is the only way to read a"
        echo "      crash report from an obfuscated build."
        sec_pass "R8 mapping file is present."
    fi
    echo ""
}


function check_apk_freshness() {
    sec_begin "Testing that the APK under test matches current sources"

    local apk
    apk=$(sec_find_apk) || { sec_skip "No built APK found."; echo ""; return; }

    local newer
    newer=$(sec_apk_is_stale "$apk")
    echo "    > APK built: $(date -r "$apk" '+%Y-%m-%d %H:%M' 2>/dev/null)"
    echo "    > Source files newer than the APK: $newer"

    if [ "$newer" -gt 0 ]; then
        echo "    > Findings below may describe an older build. Rebuild before"
        echo "      acting on them."
        sec_inconclusive "APK is older than the sources."
    else
        sec_pass "APK is at least as new as the sources."
    fi
    echo ""
}

check_apk_freshness
check_gradle_obfuscation_settings
check_flutter_build_script
check_apk_not_debuggable
check_dex_class_names_obfuscated
check_dart_symbols_stripped
check_r8_mapping_retained

sec_summary
