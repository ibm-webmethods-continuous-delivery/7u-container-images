@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-ft-test-double-t:alpine' exists
docker image inspect iwcd-ft-test-double-t:alpine >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-ft-test-double-t:alpine' not found. Building it first...
    pushd .
    cd ..\..\..\t\alpine\ft-test-double
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-ft-test-double-t:alpine' image.
        popd
        exit /b 1
    )
    popd
)

if not defined BUILD_USER_ID set BUILD_USER_ID=1001
if not defined BUILD_GROUP_ID set BUILD_GROUP_ID=1001
docker buildx build ^
  --build-arg "__ftpd_user_id=%BUILD_USER_ID%" ^
  --build-arg "__ftpd_group_gid=%BUILD_GROUP_ID%" ^
  -t iwcd-ft-test-double-u:alpine .
