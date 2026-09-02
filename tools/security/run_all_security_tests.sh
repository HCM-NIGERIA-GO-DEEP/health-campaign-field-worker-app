#!/bin/bash

# Configuration
REPORT_FILE="security_test_report.md"
SCRIPTS=("test_broadcast_receivers.sh" "test_root_detection.sh" "test_platform_usage.sh" "test_obfuscation.sh")
SCRIPT_NAMES=("Insecure Broadcast Receiver Mitigation" "Root Detection Bypass Prevention" "Improper Platform Usage Mitigation" "Improper Code Obfuscation Mitigation")

echo "==========================================================="
echo " Running All Security Tests"
echo "==========================================================="
echo ""

# Initialize Report
echo "# Application Security Testing Report" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Date:** $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "## Summary of Results" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Test Category | Passed (Secure) | Failed (Vuln) | Inconclusive | Skipped | Status |" >> "$REPORT_FILE"
echo "|---|---|---|---|---|---|" >> "$REPORT_FILE"

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_INCONCLUSIVE=0
TOTAL_SKIPPED=0
TOTAL_TESTS=0

# Create detailed section
DETAILED_SECTION=""

for i in "${!SCRIPTS[@]}"; do
    script="${SCRIPTS[$i]}"
    name="${SCRIPT_NAMES[$i]}"
    
    if [ ! -f "$script" ]; then
        echo "[!] Warning: $script not found in current directory."
        continue
    fi
    
    echo "[*] Executing $script..."
    
    # Make executable just in case
    chmod +x "$script"
    
    # Run script and capture output
    output=$(./"$script")
    
    # Extract scores using grep and regex
    passed=$(echo "$output" | grep "Passed (Secure)" | grep -o "[0-9]\+" | tail -1)
    failed=$(echo "$output" | grep "Failed (Vuln)" | grep -o "[0-9]\+" | tail -1)
    # Not every script reports these, so they default to 0.
    inconclusive=$(echo "$output" | grep "Inconclusive" | grep -o "[0-9]\+" | tail -1)
    skipped=$(echo "$output" | grep "Skipped" | grep -o "[0-9]\+" | tail -1)
    
    if [ -z "$passed" ]; then passed=0; fi
    if [ -z "$failed" ]; then failed=0; fi
    if [ -z "$inconclusive" ]; then inconclusive=0; fi
    if [ -z "$skipped" ]; then skipped=0; fi
    
    # Update totals
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    TOTAL_INCONCLUSIVE=$((TOTAL_INCONCLUSIVE + inconclusive))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + skipped))
    TOTAL_TESTS=$((TOTAL_TESTS + passed + failed + inconclusive + skipped))
    
    # A mitigation that could not be verified must not read as secure.
    status="✅ Secure"
    if [ "$failed" -gt 0 ]; then
        status="❌ Vulnerable"
    elif [ "$inconclusive" -gt 0 ] || [ "$skipped" -gt 0 ]; then
        status="⚠️ Not verified"
    fi
    
    # Add to summary table
    echo "| $name | $passed | $failed | $inconclusive | $skipped | $status |" >> "$REPORT_FILE"
    
    # Build detailed section
    DETAILED_SECTION+="\n### $name\n"
    DETAILED_SECTION+="\n\`\`\`text\n"
    DETAILED_SECTION+="$output\n"
    DETAILED_SECTION+="\`\`\`\n"
     
    echo "    > Passed: $passed, Failed: $failed, Inconclusive: $inconclusive, Skipped: $skipped"
done

# Calculate overall status
OVERALL_STATUS="✅ SECURE"
if [ "$TOTAL_FAILED" -gt 0 ]; then
    OVERALL_STATUS="❌ VULNERABLE"
elif [ "$TOTAL_INCONCLUSIVE" -gt 0 ] || [ "$TOTAL_SKIPPED" -gt 0 ]; then
    OVERALL_STATUS="⚠️ INCOMPLETE"
fi

# Add Score Summary
echo "" >> "$REPORT_FILE"
echo "## Final Score" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Total Tests Run**: $TOTAL_TESTS" >> "$REPORT_FILE"
echo "- **Total Passed (Secure)**: $TOTAL_PASSED" >> "$REPORT_FILE"
echo "- **Total Failed (Vuln)**: $TOTAL_FAILED" >> "$REPORT_FILE"
echo "- **Total Inconclusive**: $TOTAL_INCONCLUSIVE" >> "$REPORT_FILE"
echo "- **Total Skipped**: $TOTAL_SKIPPED" >> "$REPORT_FILE"
echo "- **Overall Status**: $OVERALL_STATUS" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Append Detailed Output
echo "## Detailed Execution Output" >> "$REPORT_FILE"
echo -e "$DETAILED_SECTION" >> "$REPORT_FILE"

echo ""
echo "==========================================================="
echo " All Tests Completed!"
echo " Total Passed : $TOTAL_PASSED"
echo " Total Failed : $TOTAL_FAILED"
echo " Inconclusive : $TOTAL_INCONCLUSIVE"
echo " Skipped      : $TOTAL_SKIPPED"
echo " Report generated at: $REPORT_FILE"
echo "==========================================================="
