#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Container Image Builder - macOS / Linux Wrapper
#
# Usage:
#   ./build.sh                              - Build all images
#   ./build.sh u/alpine/git-guardian        - Build specific image
#   ./build.sh t/alpine/cert-manager        - Build specific image with dependencies
#   ./build.sh --scan                       - Build all with scanning
#   ./build.sh u/alpine/git-guardian --scan - Build specific with scanning

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Defaults
BUILD_TARGET="all"
ENABLE_SCAN="false"

. .env

: "${BUILD_USER_ID:=$(id -u)}"
: "${BUILD_GROUP_ID:=$(id -g)}"

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --scan|-s)
      ENABLE_SCAN="true"
      ;;
    *)
      BUILD_TARGET="$arg"
      ;;
  esac
done

echo "==================================="
echo "Container Image Builder"
echo "==================================="
echo "Build Target:  $BUILD_TARGET"
echo "Scanning:      $ENABLE_SCAN"
echo "Build User ID: $BUILD_USER_ID"
echo "Build Group ID:$BUILD_GROUP_ID"
echo "==================================="
echo

docker compose run --rm \
  -e BUILD_TARGET="$BUILD_TARGET" \
  -e ENABLE_SCAN="$ENABLE_SCAN" \
  -e BUILD_USER_ID="$BUILD_USER_ID" \
  -e BUILD_GROUP_ID="$BUILD_GROUP_ID" \
  7u-ci-builder

echo
echo "==================================="
echo "Build completed successfully!"
if [ "$ENABLE_SCAN" = "true" ]; then
  echo "Scan results: $SCRIPT_DIR/scan-results/"
fi
echo "==================================="

# Made with Bob
