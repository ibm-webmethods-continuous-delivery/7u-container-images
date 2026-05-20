#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

# Check if the Docker image 'iwcd-az-cli-dev-s:azure-linux' exists
if ! docker image inspect iwcd-az-cli-dev-s:azure-linux >/dev/null 2>&1; then
    echo "Image 'iwcd-az-cli-dev-s:azure-linux' not found. Building it first..."
    current_dir=$(pwd)
    cd ../../../s/azure/az-cli-dev || exit 1
    sh build-local.sh
    if [ $? -ne 0 ]; then
        echo "Failed to build 'iwcd-az-cli-dev-s:azure-linux' image."
        cd "$current_dir" || exit 1
        exit 1
    fi
    cd "$current_dir" || exit 1
fi

docker buildx build -t iwcd-az-cli-dev-u:azure-linux .

# Made with Bob
