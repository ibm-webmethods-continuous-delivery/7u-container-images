@echo off

REM SPDX-License-Identifier: Apache-2.0

echo Building image iwcd-vm-emu-min-pu-u:ubi9 ...

REM Check if the Docker image 'iwcd-vm-emu-min-pu-t:ubi9' exists
docker image inspect iwcd-vm-emu-min-pu-t:ubi9 >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-vm-emu-min-pu-t:ubi9' not found. Building it first...
    pushd .
    cd ..\..\..\..\..\t\ubi9\iwcd-vm-emu-min-pu
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-vm-emu-min-pu-t:ubi9' image.
        popd
        exit /b 1
    )
    popd
)

if not defined BUILD_USER_ID set BUILD_USER_ID=1001
if not defined BUILD_GROUP_ID set BUILD_GROUP_ID=1001
docker buildx build ^
  --build-arg "__from_image=iwcd-vm-emu-min-pu-t:ubi9" ^
  --build-arg "__user_id=%BUILD_USER_ID%" ^
  --build-arg "__group_id=%BUILD_GROUP_ID%" ^
  --no-cache ^
  -t iwcd-vm-emu-min-pu-u:ubi9 ..

echo Built image iwcd-vm-emu-min-pu-u:ubi9.
