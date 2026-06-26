#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

# Check if the Docker image 'iwcd-edge-debug:latest' exists
if ! docker image inspect iwcd-edge-debug:latest > /dev/null 2>&1; then
    echo "Image 'iwcd-edge-debug:latest' not found. Building it first..."
    ( cd ../debug && sh build-local.sh ) || {
        echo "Failed to build 'iwcd-edge-debug:latest' image."
        exit 1
    }
fi

# Load WPM_TOKEN from set-env.sh if not already set in the environment
if [ -z "${WPM_TOKEN}" ] && [ -f ./set-env.sh ]; then
    # shellcheck source=./set-env.sh
    . ./set-env.sh
fi

# Fail early rather than passing an empty secret into the build
if [ -z "${WPM_TOKEN}" ]; then
    echo "ERROR: WPM_TOKEN is not set. Set it in your environment or in set-env.sh."
    exit 1
fi

# --secret passes the token only as a tmpfs mount; it is never stored in any image layer.
docker buildx build --secret id=wpm_token,env=WPM_TOKEN -t iwcd-edge-debug-jdbc:latest .
