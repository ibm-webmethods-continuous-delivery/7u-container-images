#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

# Check if the Docker image 'iwcd-cert-manager-t:alpine' exists
if ! docker image inspect iwcd-cert-manager-t:alpine >/dev/null 2>&1; then
    echo "Image 'iwcd-cert-manager-t:alpine' not found. Building it first..."
    current_dir=$(pwd)
    cd ../../../t/alpine/cert-manager || exit 1
    sh build-local.sh
    if [ $? -ne 0 ]; then
        echo "Failed to build 'iwcd-cert-manager-t:alpine' image."
        cd "$current_dir" || exit 1
        exit 1
    fi
    cd "$current_dir" || exit 1
fi

docker buildx build -t iwcd-cert-manager-u:alpine .

# Made with Bob
