@echo off

REM SPDX-License-Identifier: Apache-2.0

echo Building image iwcd-vm-emu-min-wmui-u:ubi9 ...

REM Check if the Docker image 'iwcd-vm-emu-min-wmui-t:ubi9' exists
docker image inspect iwcd-vm-emu-min-wmui-t:ubi9 >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-vm-emu-min-wmui-t:ubi9' not found. Building it first...
    pushd .
    cd ..\..\..\..\t\ubi9\iwcd-vm-emu-min-wmui
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-vm-emu-min-wmui-t:ubi9' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build ^
--build-arg "__from_image=iwcd-vm-emu-min-wmui-t:ubi9" ^
--no-cache ^
-t iwcd-vm-emu-min-wmui-u:ubi9 .

echo Built image iwcd-vm-emu-min-wmui-u:ubi9.
