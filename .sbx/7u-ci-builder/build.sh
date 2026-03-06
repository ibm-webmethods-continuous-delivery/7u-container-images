#!/bin/sh
#
# SPDX-License-Identifier: Apache-2.0
#
# Container Image Builder Script
# This script builds container images with dependency resolution
# and optional security scanning
#
# Usage:
#   BUILD_TARGET=all ./build.sh                    # Build all images
#   BUILD_TARGET=all ENABLE_SCAN=true ./build.sh   # Build all with scanning
#   BUILD_TARGET=u/alpine/git-guardian ./build.sh  # Build specific image
#   BUILD_TARGET=u/alpine/git-guardian ENABLE_SCAN=true ./build.sh  # Build with scanning

# shellcheck disable=SC3043
set -e

# Default to building all if not specified
BUILD_TARGET="${BUILD_TARGET:-all}"
ENABLE_SCAN="${ENABLE_SCAN:-false}"

# Create session ID for this build/scan run
SCAN_SESSION=$(date +%Y%m%d_%H%M%S)
export SCAN_SESSION

echo "==================================="
echo "Container Image Builder"
echo "==================================="
echo "Build Target: $BUILD_TARGET"
echo "Scanning: $ENABLE_SCAN"
if [ "$ENABLE_SCAN" = "true" ]; then
    echo "Scan Session: $SCAN_SESSION"
fi
echo "==================================="

# Source scanning functions if enabled
if [ "$ENABLE_SCAN" = "true" ]; then
    if [ -f "/workspace/.sbx/7u-ci-builder/scan.sh" ]; then
        # shellcheck source=SCRIPTDIR/scan.sh
        . /workspace/.sbx/7u-ci-builder/scan.sh

        # Create session directory
        SESSION_DIR="/scan-results/session_${SCAN_SESSION}"
        mkdir -p "$SESSION_DIR"
        export SESSION_DIR

        # Initialize session summary
        init_session_summary

        echo "✓ Scanning enabled (hadolint + trivy)"
        echo "✓ Session directory: $SESSION_DIR"
    else
        echo "⚠ Warning: scan.sh not found, scanning disabled"
        ENABLE_SCAN="false"
    fi
fi

# Change to workspace images directory
cd /workspace/images || exit 1

# Function to extract image tag from build script
extract_image_tag() {
    local script_path="${1}"
    # Try to extract the -t parameter from docker buildx build command
    grep -o -- '-t [^ ]*' "$script_path" 2>/dev/null | head -1 | cut -d' ' -f2 || echo ""
}

# Function to find all build-local*.sh scripts in a layer
find_build_scripts() {
    local layer="${1}"
    find "$layer" -type f -name "build-local*.sh" 2>/dev/null | sort
}

# Function to build a single image from a script
build_image() {
    local script_path="${1}"
    local image_dir
    local script_name
    image_dir=$(dirname "$script_path")
    script_name=$(basename "$script_path")

    echo ">>> Building: $image_dir ($script_name)"

    if [ ! -f "/workspace/images/$script_path" ]; then
        echo "WARNING: Script not found: $script_path, skipping..."
        return 0
    fi

    # Run hadolint before build if scanning enabled
    local hadolint_result=""
    if [ "$ENABLE_SCAN" = "true" ]; then
        local scan_name
        scan_name=$(echo "$image_dir" | tr '/' '_')
        if [ "$script_name" != "build-local.sh" ]; then
            local variant
            variant=$(echo "$script_name" | sed 's/build-local-\(.*\)\.sh/\1/')
            scan_name="${scan_name}_${variant}"
        fi

        # Put detailed scan results in details subdirectory
        local output_dir="$SESSION_DIR/details/$scan_name"
        mkdir -p "$output_dir"

        echo "  🔍 Pre-build: Running hadolint..."
        local dockerfile="/workspace/images/$image_dir/Dockerfile"
        hadolint_result=$(run_hadolint "$dockerfile" "$output_dir" "$scan_name")
    fi

    # Build the image
    cd "/workspace/images/$image_dir" || return 1
    sh "$script_name"
    local result=$?

    if [ $result -ne 0 ]; then
        echo "ERROR: Failed to build $image_dir with $script_name"
        return 1
    fi

    echo "SUCCESS: Built $image_dir with $script_name"

    # Run trivy after build if scanning enabled
    if [ "$ENABLE_SCAN" = "true" ]; then
        local image_tag
        image_tag=$(extract_image_tag "/workspace/images/$script_path")
        if [ -n "$image_tag" ]; then
            echo "  🔍 Post-build: Running trivy on $image_tag..."
            local scan_name
            scan_name=$(echo "$image_dir" | tr '/' '_')
            if [ "$script_name" != "build-local.sh" ]; then
                local variant
                variant=$(echo "$script_name" | sed 's/build-local-\(.*\)\.sh/\1/')
                scan_name="${scan_name}_${variant}"
            fi
            # Put detailed scan results in details subdirectory
            local output_dir="$SESSION_DIR/details/$scan_name"

            # Run trivy and capture results
            local trivy_result
            trivy_result=$(run_trivy "$image_tag" "$output_dir" "$scan_name")

            # Parse vulnerability counts
            local critical high medium low
            critical=$(echo "$trivy_result" | cut -d: -f1)
            high=$(echo "$trivy_result" | cut -d: -f2)
            medium=$(echo "$trivy_result" | cut -d: -f3)
            low=$(echo "$trivy_result" | cut -d: -f4)

            # Detect secrets and misconfigurations
            local secrets_misconfig secrets misconfig
            secrets_misconfig=$(detect_secrets_and_misconfig "$image_tag" "$output_dir")
            secrets=$(echo "$secrets_misconfig" | cut -d: -f1)
            misconfig=$(echo "$secrets_misconfig" | cut -d: -f2)

            # Determine overall status
            local overall_status="N/A"
            if [ "$critical" -gt 0 ]; then
                overall_status="CRITICAL"
            elif [ "$high" -gt 0 ]; then
                overall_status="HIGH"
            elif [ "$medium" -gt 0 ]; then
                overall_status="MEDIUM"
            elif [ "$low" -gt 0 ]; then
                overall_status="LOW"
            else
                overall_status="CLEAN"
            fi

            # Add to session summary
            echo "  📝 Adding to session summary..."
            add_to_session_summary "$image_tag" "$hadolint_result" "$critical" "$high" "$medium" "$low" "$secrets" "$misconfig" "$overall_status"
        else
            echo "  ⚠ Could not extract image tag, skipping trivy scan"
        fi
    fi

    echo ""
    return 0
}


if [ "$BUILD_TARGET" = "all" ]; then
    echo "Discovering all images to build..."
    echo "Building in dependency order: s → t → u"
    echo ""

    total_built=0
    total_failed=0

    # Build in layers: s (system/base), t (tools), u (user)
    _l_crt_path=$(pwd)
    for layer in s t u; do
        if [ ! -d "$layer" ]; then
            echo "Layer '$layer' not found, skipping..."
            continue
        fi

        echo "==================================="
        echo "Building layer: $layer"
        echo "==================================="
        echo ""

        # Find all build-local*.sh scripts in this layer
        build_scripts=$(find_build_scripts "$layer")

        if [ -z "$build_scripts" ]; then
            echo "No build scripts found in layer '$layer'"
            echo ""
            continue
        fi

        # Build each image in this layer
        echo "$build_scripts" > "/dev/shm/build_scripts_$(date +%s).txt"

        while read -r script_path; do
            if [ -n "$script_path" ]; then
                if build_image "$script_path"; then
                    total_built=$((total_built + 1))
                else
                    total_failed=$((total_failed + 1))
                    # Continue building other images even if one fails
                fi
            fi
        done < "/dev/shm/build_scripts_$(date +%s).txt"

        echo ""
        cd "$_l_crt_path" || exit 2
    done

    echo "==================================="
    echo "Build Summary"
    echo "==================================="
    echo "All layers processed (s → t → u)"
    if [ "$ENABLE_SCAN" = "true" ]; then
        echo "Scan results: $SESSION_DIR"
        echo "Session summary: $SESSION_DIR/session_summary.md"
        echo ""

        # Format the table for better readability
        format_summary_table "$SESSION_DIR/session_summary.md"

        echo "📊 Session Summary Preview:"
        if [ -f "$SESSION_DIR/session_summary.md" ]; then
            tail -n +4 "$SESSION_DIR/session_summary.md"
        fi
    fi
    echo ""

    if [ $total_failed -gt 0 ]; then
        echo "WARNING: Some builds failed"
        echo "Check the output above for details"
        exit 3
    else
        echo "All builds completed successfully!"
    fi
    echo "==================================="
else
    # Build specific image
    echo "Building specific image: $BUILD_TARGET"
    echo ""

    # Validate path exists
    if [ ! -d "$BUILD_TARGET" ]; then
        echo "ERROR: Directory not found: $BUILD_TARGET"
        echo "Please provide a valid path relative to /workspace/images/"
        echo "Examples:"
        echo "  - s/alpine/iwcd-aio-base"
        echo "  - t/alpine/cert-manager"
        echo "  - u/alpine/git-guardian"
        exit 4
    fi

    # Check if build-local.sh exists
    if [ ! -f "$BUILD_TARGET/build-local.sh" ]; then
        echo "ERROR: build-local.sh not found in $BUILD_TARGET"
        exit 5
    fi

    # Build with scanning support
    if build_image "$BUILD_TARGET/build-local.sh"; then
        echo ""
        echo "==================================="
        echo "Build completed successfully!"
        if [ "$ENABLE_SCAN" = "true" ]; then
            echo "Scan results: $SESSION_DIR"
            echo "Session summary: $SESSION_DIR/session_summary.md"
            echo ""

            # Format the table for better readability
            format_summary_table "$SESSION_DIR/session_summary.md"

            echo "📊 Session Summary:"
            if [ -f "$SESSION_DIR/session_summary.md" ]; then
                tail -n +4 "$SESSION_DIR/session_summary.md"
            fi
        fi
        echo "==================================="
    else
        echo ""
        echo "==================================="
        echo "Build FAILED!"
        echo "==================================="
        exit 6
    fi
fi

# Made with Bob
