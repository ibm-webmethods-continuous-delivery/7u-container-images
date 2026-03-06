#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

# Check if the Docker image 'iwcd-ft-test-double-t:alpine' exists
if ! docker image inspect iwcd-ft-test-double-t:alpine >/dev/null 2>&1; then
    echo "Image 'iwcd-ft-test-double-t:alpine' not found. Building it first..."
    current_dir=$(pwd)
    cd ../../../t/alpine/ft-test-double || exit 1
    sh build-local.sh
    if [ $? -ne 0 ]; then
        echo "Failed to build 'iwcd-ft-test-double-t:alpine' image."
        cd "$current_dir" || exit 1
        exit 1
    fi
    cd "$current_dir" || exit 1
fi

docker buildx build -t iwcd-ft-test-double-u:alpine .

# Made with Bob
