#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

# Check if the Docker image 'iwcd-aio-base-s:alpine' exists
if ! docker image inspect iwcd-aio-base-s:alpine >/dev/null 2>&1; then
    echo "Image 'iwcd-aio-base-s:alpine' not found. Building it first..."
    current_dir=$(pwd)
    cd ../../../s/alpine/iwcd-aio-base || exit 1
    sh build-local.sh
    if [ $? -ne 0 ]; then
        echo "Failed to build 'iwcd-aio-base-s:alpine' image."
        cd "$current_dir" || exit 1
        exit 1
    fi
    cd "$current_dir" || exit 1
fi

docker buildx build -t iwcd-aio-base-t:alpine .

# Made with Bob
