#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

# Check if the Docker image 'iwcd-aio-base-t:alpine' exists
if ! docker image inspect iwcd-aio-base-t:alpine >/dev/null 2>&1; then
    echo "Image 'iwcd-aio-base-t:alpine' not found. Building it first..."
    current_dir=$(pwd)
    cd ../../../t/alpine/iwcd-aio-base || exit 1
    sh build-local.sh
    if [ $? -ne 0 ]; then
        echo "Failed to build 'iwcd-aio-base-t:alpine' image."
        cd "$current_dir" || exit 1
        exit 1
    fi
    cd "$current_dir" || exit 1
fi

docker buildx build -t iwcd-aio-base-u:alpine .

# Made with Bob
