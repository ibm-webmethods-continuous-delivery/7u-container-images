#!/bin/sh

# Copyright 2026 IBM Corporation
# SPDX-License-Identifier: Apache-2.0

# Check if the Docker image 'iwcd-vm-emu-min-pu-t:ubi9' exists
if ! docker image inspect iwcd-vm-emu-min-pu-t:ubi9 >/dev/null 2>&1; then
    echo "Image 'iwcd-vm-emu-min-pu-t:ubi9' not found. Building it first..."
    current_dir=$(pwd)
    cd ../iwcd-vm-emu-min-pu || exit 1
    sh build-local.sh
    if [ $? -ne 0 ]; then
        echo "Failed to build 'iwcd-vm-emu-min-pu-t:ubi9' image."
        cd "$current_dir" || exit 1
        exit 1
    fi
    cd "$current_dir" || exit 1
fi

docker buildx build \
--no-cache \
-t iwcd-vm-emu-min-wmui-t:ubi9 .

# Made with Bob
