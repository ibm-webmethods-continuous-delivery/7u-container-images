@echo off

REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'vm-emu-min-wmui-t:ubi9' exists

docker image inspect vm-emu-min-wmui-t:ubi9 >nul 2>&1
if errorlevel 1 (
    echo Image 'vm-emu-min-wmui-t:ubi9' not found. Building it first...
    pushd .
    cd ..\..\..\..\s\ubi9\vm-emu\minimal
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'vm-emu-min-wmui-t:ubi9' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build ^
--build-arg "__from_image=vm-emu-min-wmui-t:ubi9" ^
--no-cache ^
-t vm-emu-min-wmui-u:ubi9 .
