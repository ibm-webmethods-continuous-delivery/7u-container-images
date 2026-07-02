@echo off
REM Build script for ft-test-client U-tier
REM Copyright IBM Corp. 2026 - 2026
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-ft-test-client-t:alpine' exists
docker image inspect iwcd-ft-test-client-t:alpine >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-ft-test-client-t:alpine' not found. Building it first...
    pushd .
    cd ..\..\..\t\alpine\ft-test-client
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-ft-test-client-t:alpine' image.
        popd
        exit /b 1
    )
    popd
)

if not defined BUILD_USER_ID set BUILD_USER_ID=1001
if not defined BUILD_GROUP_ID set BUILD_GROUP_ID=1001
docker buildx build ^
  --build-arg "__test_user_id=%BUILD_USER_ID%" ^
  --build-arg "__test_group_gid=%BUILD_GROUP_ID%" ^
  --progress=plain ^
  -t iwcd-ft-test-client-u:alpine .

@REM Made with Bob
