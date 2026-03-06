#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

set -e

echo "==================================="
echo "Building all container images"
echo "==================================="
echo "Building in dependency order: s → t → u"
echo ""

# Save current directory
start_dir=$(pwd)

# Function to find all build-local*.sh scripts in a layer
find_build_scripts() {
    local layer=$1
    find "$layer" -type f -name "build-local*.sh" 2>/dev/null | sort
}

# Function to build a single image from a script
build_image() {
    local script_path=$1
    local image_dir=$(dirname "$script_path")
    local script_name=$(basename "$script_path")

    echo ">>> Building: $image_dir ($script_name)"

    cd "$start_dir/$image_dir" || return 1
    sh "$script_name"
    local result=$?

    if [ $result -ne 0 ]; then
        echo "ERROR: Failed to build $image_dir with $script_name"
        return 1
    fi

    echo "SUCCESS: Built $image_dir with $script_name"
    echo ""
    return 0
}

total_built=0
total_failed=0

# Build in layers: s (system/base), t (tools), u (user)
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
    echo "$build_scripts" | while read -r script_path; do
        if [ -n "$script_path" ]; then
            if build_image "$script_path"; then
                total_built=$((total_built + 1))
            else
                total_failed=$((total_failed + 1))
                # Continue building other images even if one fails
            fi
        fi
    done

    echo ""
done

echo "==================================="
echo "Build Summary"
echo "==================================="
echo "All layers processed (s → t → u)"
echo ""

if [ $total_failed -gt 0 ]; then
    echo "WARNING: Some builds failed"
    echo "Check the output above for details"
    exit 1
else
    echo "All builds completed successfully!"
fi
echo "==================================="

# Made with Bob
