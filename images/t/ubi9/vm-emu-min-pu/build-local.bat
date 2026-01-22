@echo off

REM Copyright 2026 IBM Corporation
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'vm-emu-minimal-s:ubi9' exists

docker image inspect vm-emu-minimal-s:ubi9 >nul 2>&1
if errorlevel 1 (
    echo Image 'vm-emu-minimal-s:ubi9' not found. Building it first...
    pushd .
    cd ..\..\..\s\ubi9\vm-emu\minimal
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'vm-emu-minimal-s:ubi9' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build -t vm-emu-min-pu-t:ubi9 .
