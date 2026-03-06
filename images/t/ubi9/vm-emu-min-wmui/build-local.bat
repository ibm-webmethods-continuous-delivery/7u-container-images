@echo off

REM Copyright 2026 IBM Corporation
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-vm-emu-min-pu-t:ubi9' exists

docker image inspect iwcd-vm-emu-min-pu-t:ubi9 >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-vm-emu-min-pu-t:ubi9' not found. Building it first...
    pushd .
    cd ..\iwcd-vm-emu-min-pu
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-vm-emu-min-pu-t:ubi9' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build ^
--no-cache ^
-t iwcd-vm-emu-min-wmui-t:ubi9 .
