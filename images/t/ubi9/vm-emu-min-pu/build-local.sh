#!/bin/sh

# Copyright 2026 IBM Corporation
# SPDX-License-Identifier: Apache-2.0

echo "Building image iwcd-vm-emu-min-pu-t:ubi9 ..."

# Check if the Docker image 'iwcd-iwcd-vm-emu-minimal-s:ubi9' exists
if ! docker image inspect iwcd-iwcd-vm-emu-minimal-s:ubi9 >/dev/null 2>&1; then
    echo "Image 'iwcd-iwcd-vm-emu-minimal-s:ubi9' not found. Building it first..."
    current_dir=$(pwd)
    cd ../../../s/ubi9/vm-emu/minimal || exit 1
    sh build-local.sh
    if [ $? -ne 0 ]; then
        echo "Failed to build 'iwcd-iwcd-vm-emu-minimal-s:ubi9' image."
        cd "$current_dir" || exit 1
        exit 1
    fi
    cd "$current_dir" || exit 1
fi

docker buildx build \
--no-cache \
-t iwcd-vm-emu-min-pu-t:ubi9 .

echo "Built image iwcd-vm-emu-min-pu-t:ubi9."

# Made with Bob
