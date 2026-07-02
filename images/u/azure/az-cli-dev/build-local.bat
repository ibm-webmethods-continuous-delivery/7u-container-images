@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-az-cli-dev-s:azure-linux' exists

docker image inspect iwcd-az-cli-dev-s:azure-linux >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-az-cli-dev-s:azure-linux' not found. Building it first...
    pushd .
    cd ..\..\..\s\azure\az-cli-dev
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-az-cli-dev-s:azure-linux' image.
        popd
        exit /b 1
    )
    popd
)

if not defined BUILD_USER_ID set BUILD_USER_ID=1001
if not defined BUILD_GROUP_ID set BUILD_GROUP_ID=1001
docker buildx build ^
  --build-arg "__uid=%BUILD_USER_ID%" ^
  --build-arg "__gid=%BUILD_GROUP_ID%" ^
  -t iwcd-az-cli-dev-u:azure-linux .
