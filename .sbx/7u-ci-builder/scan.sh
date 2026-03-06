#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
#
# Container Image Scanning Script
# Performs hadolint (Dockerfile) and trivy (image) scans with session management

# Linting exception: we accept local keyword, it works with our arrangements
# shellcheck disable=SC3043

# Initialize session summary
init_session_summary() {
    SUMMARY_FILE="$SESSION_DIR/session_summary.md"

    cat > "$SUMMARY_FILE" << 'EOF'
# Container Image Scan Session Summary

**Session ID:** SESSION_ID_PLACEHOLDER
**Date:** DATE_PLACEHOLDER

## Scan Results

| Image | Hadolint | Critical | High | Medium | Low | Secrets | Misconfig | Status |
|-------|----------|----------|------|--------|-----|---------|-----------|--------|
EOF

    # Replace placeholders
    local current_date
    current_date=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    sed -i "s/SESSION_ID_PLACEHOLDER/$SCAN_SESSION/g" "$SUMMARY_FILE" 2>/dev/null || \
        sed -i '' "s/SESSION_ID_PLACEHOLDER/$SCAN_SESSION/g" "$SUMMARY_FILE"

    sed -i "s/DATE_PLACEHOLDER/$current_date/g" "$SUMMARY_FILE" 2>/dev/null || \
        sed -i '' "s/DATE_PLACEHOLDER/$current_date/g" "$SUMMARY_FILE"
}

# Add entry to session summary
add_to_session_summary() {
    local image_name="$1"
    local hadolint_status="$2"
    local critical="$3"
    local high="$4"
    local medium="$5"
    local low="$6"
    local secrets="$7"
    local misconfig="$8"
    local overall_status="$9"

    echo "| $image_name | $hadolint_status | $critical | $high | $medium | $low | $secrets | $misconfig | $overall_status |" >> "$SUMMARY_FILE"
}

# Format and align the markdown table for better readability
format_summary_table() {
    local summary_file="$1"

    if [ ! -f "$summary_file" ]; then
        return 1
    fi

    # Extract the table part (lines 6 onwards), skip empty lines
    local temp_table
    temp_table=$(mktemp)
    sed -n '6,$p' "$summary_file" | grep -v '^[[:space:]]*$' > "$temp_table"

    # Use awk to calculate column widths and format (BusyBox compatible)
    awk -F'|' '
    function count_special_chars(str) {
        # Count special UTF-8 chars that take more bytes than display width
        count = 0
        # Check for checkmark ✓ (U+2713)
        if (index(str, "\342\234\223") > 0) count++
        # Check for warning ⚠ (U+26A0)
        if (index(str, "\342\232\240") > 0) count++
        # Check for white check mark ✅ (U+2705)
        if (index(str, "\342\234\205") > 0) count++
        # Check for orange circle 🟠 (U+1F7E0)
        if (index(str, "\360\237\237\240") > 0) count++
        # Check for yellow circle 🟡 (U+1F7E1)
        if (index(str, "\360\237\237\241") > 0) count++
        return count
    }
    function count_wide_emojis(str) {
        # Count emojis that display as 2 character widths
        count = 0
        # ✅ (3 bytes) displays as ~2 chars
        if (index(str, "\342\234\205") > 0) count++
        # 🟠 (4 bytes) displays as ~2 chars
        if (index(str, "\360\237\237\240") > 0) count++
        # 🟡 (4 bytes) displays as ~2 chars
        if (index(str, "\360\237\237\241") > 0) count++
        return count
    }
    function count_narrow_chars(str) {
        # Count chars that display as ~1 character width
        count = 0
        # ✓ (3 bytes) displays as ~1 char
        if (index(str, "\342\234\223") > 0) count++
        # ⚠ (3 bytes) displays as ~1 char
        if (index(str, "\342\232\240") > 0) count++
        return count
    }
    function visual_length(str) {
        # Calculate visual width accounting for emoji display widths
        len = length(str)
        wide = count_wide_emojis(str)
        narrow = count_narrow_chars(str)
        # Wide emojis: 3-4 bytes display as ~2 chars (subtract 1-2)
        # Narrow chars: 3 bytes display as ~1 char (subtract 2)
        return len - wide - (narrow * 2)
    }
    function pad(str, width) {
        result = str
        current_len = visual_length(result)
        while (current_len < width) {
            result = result " "
            current_len++
        }
        return result
    }
    BEGIN {
        # Initialize max widths
        for (i=1; i<=10; i++) max[i] = 0
    }
    NR==FNR {
        # First pass: calculate max widths
        for (i=2; i<NF; i++) {
            cell = $i
            gsub(/^[ \t]+|[ \t]+$/, "", cell)
            len = visual_length(cell) + 2  # Add padding
            if (len > max[i]) max[i] = len
        }
        next
    }
    {
        # Skip lines with less than 3 fields (empty or malformed)
        if (NF < 3) next
        # Second pass: format output
        printf "|"
        for (i=2; i<NF; i++) {
            cell = $i
            gsub(/^[ \t]+|[ \t]+$/, "", cell)
            printf " %s |", pad(cell, max[i]-2)
        }
        printf "\n"
    }
    ' "$temp_table" "$temp_table" > "${temp_table}.formatted"

    # Replace the table in the original file
    {
        sed -n '1,5p' "$summary_file"
        cat "${temp_table}.formatted"
    } > "${summary_file}.tmp"

    mv "${summary_file}.tmp" "$summary_file"
    rm -f "$temp_table" "${temp_table}.formatted"
}

# Function to run hadolint scan on Dockerfile
run_hadolint() {
    local dockerfile_path="$1"
    local output_dir="$2"
    local scan_name="$3"

    echo "  → Running hadolint on $dockerfile_path..." >&2

    if [ ! -f "$dockerfile_path" ]; then
        echo "  ⚠ Dockerfile not found: $dockerfile_path" >&2
        echo "❌ NOT FOUND"
        return 1
    fi

    local output_file="$output_dir/${scan_name}_hadolint.txt"

    hadolint "$dockerfile_path" > "$output_file" 2>&1
    local result=$?

    if [ $result -eq 0 ]; then
        echo "  ✓ Hadolint: PASSED (no issues)" | tee -a "$output_file" >&2
        echo "PASS"
    else
        # Count all issues: both DL (hadolint) and SC (shellcheck) codes
        local issue_count
        # TODO: resolve this shellcheck ignore
        # shellcheck disable=SC2126
        issue_count=$(grep -E "(DL|SC)[0-9]" "$output_file" 2>/dev/null | wc -l | tr -d ' \n')
        issue_count=${issue_count:-0}
        echo "  ⚠ Hadolint: Found $issue_count issues (see $output_file)" >&2
        echo "WARN $issue_count"
    fi
}

# Function to detect secrets and misconfigurations
detect_secrets_and_misconfig() {
    local image_name="$1"
    local output_dir="$2"

    echo "  → Checking for secrets and misconfigurations..." >&2

    # Run trivy for secrets and count using jq
    local secrets_count
    secrets_count=$(trivy image --scanners secret --format json "$image_name" 2>/dev/null | \
        jq '[.Results[]?.Secrets[]?] | length' 2>/dev/null || echo "0")
    secrets_count=${secrets_count:-0}

    # Run trivy for misconfigurations and count using jq
    local misconfig_count
    misconfig_count=$(trivy image --scanners config --format json "$image_name" 2>/dev/null | \
        jq '[.Results[]?.Misconfigurations[]?] | length' 2>/dev/null || echo "0")
    misconfig_count=${misconfig_count:-0}

    echo "  📋 Secrets: $secrets_count, Misconfigurations: $misconfig_count" >&2

    echo "$secrets_count:$misconfig_count"
}

# Function to run trivy scan on image
run_trivy() {
    local image_name="$1"
    local output_dir="$2"
    local scan_name="$3"

    echo "  → Running trivy on $image_name..." >&2

    # Check if image exists
    if ! docker image inspect "$image_name" >/dev/null 2>&1; then
        echo "  ⚠ Image not found: $image_name" >&2
        echo "0:0:0:0"
        return 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local base_output="$output_dir/${scan_name}_trivy_${timestamp}"

    # Run trivy scan with multiple output formats
    echo "  → Scanning for vulnerabilities..." >&2

    # JSON format (detailed)
    trivy image --format json --output "${base_output}.json" "$image_name" 2>&1 | grep -v "^$" >&2

    # Table format (human readable)
    trivy image --format table --output "${base_output}.txt" "$image_name" 2>&1 | grep -v "^$" >&2

    # SARIF format (for CI/CD integration)
    trivy image --format sarif --output "${base_output}.sarif" "$image_name" 2>&1 | grep -v "^$" >&2

    # CycloneDX SBOM (Software Bill of Materials) with vulnerabilities and licenses
    echo "  → Generating CycloneDX SBOM (with vulnerabilities & licenses)..." >&2
    trivy image --format cyclonedx --scanners vuln,license --output "${base_output}_sbom.json" "$image_name" 2>&1 | grep -v "^$" >&2

    # SPDX SBOM (alternative SBOM format) with vulnerabilities and licenses
    echo "  → Generating SPDX SBOM (with vulnerabilities & licenses)..." >&2
    trivy image --format spdx-json --scanners vuln,license --output "${base_output}_sbom_spdx.json" "$image_name" 2>&1 | grep -v "^$" >&2

    # Summary with severity counts - use jq to parse the already-saved JSON file
    echo "  → Generating summary..." >&2

    # Read from the JSON file we just created and count vulnerabilities by severity
    local critical
    critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "${base_output}.json" 2>/dev/null || echo "0")
    local high
    high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "${base_output}.json" 2>/dev/null || echo "0")
    local medium
    medium=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' "${base_output}.json" 2>/dev/null || echo "0")
    local low
    low=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="LOW")] | length' "${base_output}.json" 2>/dev/null || echo "0")

    # Save summary to file for reference
    {
        echo "Vulnerability counts by severity:" > "${base_output}_summary.txt"
        echo "CRITICAL: $critical"
        echo "HIGH: $high"
        echo "MEDIUM: $medium"
        echo "LOW: $low"
    } > "${base_output}_summary.txt"

    # Ensure we have numeric values
    critical=${critical:-0}
    high=${high:-0}
    medium=${medium:-0}
    low=${low:-0}

    echo "  📊 Vulnerability Summary:" | tee -a "${base_output}_summary.txt" >&2
    echo "     CRITICAL: $critical" | tee -a "${base_output}_summary.txt" >&2
    echo "     HIGH:     $high" | tee -a "${base_output}_summary.txt" >&2
    echo "     MEDIUM:   $medium" | tee -a "${base_output}_summary.txt" >&2
    echo "     LOW:      $low" | tee -a "${base_output}_summary.txt" >&2

    # Classification
    if [ "$critical" -gt 0 ]; then
        echo "  🔴 Classification: CRITICAL - Immediate action required" | tee -a "${base_output}_summary.txt" >&2
    elif [ "$high" -gt 0 ]; then
        echo "  🟠 Classification: HIGH - Action recommended" | tee -a "${base_output}_summary.txt" >&2
    elif [ "$medium" -gt 0 ]; then
        echo "  🟡 Classification: MEDIUM - Review recommended" | tee -a "${base_output}_summary.txt" >&2
    elif [ "$low" -gt 0 ]; then
        echo "  🟢 Classification: LOW - Minor issues" | tee -a "${base_output}_summary.txt" >&2
    else
        echo "  ✅ Classification: CLEAN - No vulnerabilities found" | tee -a "${base_output}_summary.txt" >&2
    fi

    echo "  ✓ Trivy scan complete" >&2
    echo "     Results: ${base_output}.*" >&2

    # Return vulnerability counts for summary
    echo "$critical:$high:$medium:$low"
}

# Main scanning function
scan_image() {
    local image_dir="$1"
    local script_name="$2"
    local image_tag="$3"

    # Create output directory for this scan in session folder
    local scan_name
    scan_name=$(echo "$image_dir" | tr '/' '_')
    if [ "$script_name" != "build-local.sh" ]; then
        local variant
        variant=$(echo "$script_name" | sed 's/build-local-\(.*\)\.sh/\1/')
        scan_name="${scan_name}_${variant}"
    fi

    local output_dir="$SESSION_DIR/$scan_name"
    mkdir -p "$output_dir"

    echo ""
    echo "🔍 Scanning: $image_dir ($script_name)"
    echo "   Output: $output_dir"

    # Run hadolint on Dockerfile
    local dockerfile="/workspace/images/$image_dir/Dockerfile"
    local hadolint_result
    hadolint_result=$(run_hadolint "$dockerfile" "$output_dir" "$scan_name")

    # Initialize summary variables
    local critical=0 high=0 medium=0 low=0 secrets=0 misconfig=0
    local overall_status="N/A"

    # Run trivy on built image (if image tag provided)
    if [ -n "$image_tag" ]; then
        local trivy_result
        trivy_result=$(run_trivy "$image_tag" "$output_dir" "$scan_name")
        echo "  🔍 DEBUG: trivy_result='$trivy_result'" >&2

        # Parse vulnerability counts
        critical=$(echo "$trivy_result" | cut -d: -f1)
        high=$(echo "$trivy_result" | cut -d: -f2)
        medium=$(echo "$trivy_result" | cut -d: -f3)
        low=$(echo "$trivy_result" | cut -d: -f4)

        echo "  🔍 DEBUG: Parsed values - C:$critical H:$high M:$medium L:$low" >&2

        # Detect secrets and misconfigurations
        local secrets_misconfig
        secrets_misconfig=$(detect_secrets_and_misconfig "$image_tag" "$output_dir")
        secrets=$(echo "$secrets_misconfig" | cut -d: -f1)
        misconfig=$(echo "$secrets_misconfig" | cut -d: -f2)

        # Determine overall status
        if [ "$critical" -gt 0 ]; then
            overall_status="🔴 CRITICAL"
        elif [ "$high" -gt 0 ]; then
            overall_status="HIGH"
        elif [ "$medium" -gt 0 ]; then
            overall_status="MEDIUM"
        elif [ "$low" -gt 0 ]; then
            overall_status="LOW"
        else
            overall_status="CLEAN"
        fi
    else
        echo "  ⚠ No image tag provided, skipping trivy scan"
        overall_status="SKIPPED"
    fi

    # Add to session summary
    echo "  📝 Adding to session summary..."
    add_to_session_summary "$image_tag" "$hadolint_result" "$critical" "$high" "$medium" "$low" "$secrets" "$misconfig" "$overall_status"

    echo "✓ Scan complete for $image_dir"
    echo ""
}

# Functions are sourced, no need to export in POSIX sh

# Made with Bob
