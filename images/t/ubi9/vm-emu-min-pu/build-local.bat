@echo off

REM Copyright 2026 IBM Corporation
REM SPDX-License-Identifier: Apache-2.0

echo Building image iwcd-vm-emu-min-pu-t:ubi9 ...

REM Check if the Docker image 'iwcd-iwcd-vm-emu-minimal-s:ubi9' exists
docker image inspect iwcd-iwcd-vm-emu-minimal-s:ubi9 >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-iwcd-vm-emu-minimal-s:ubi9' not found. Building it first...
    pushd .
    cd ..\..\..\s\ubi9\vm-emu\minimal
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-iwcd-vm-emu-minimal-s:ubi9' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build ^
--no-cache ^
-t iwcd-vm-emu-min-pu-t:ubi9 .

echo Built image iwcd-vm-emu-min-pu-t:ubi9.
