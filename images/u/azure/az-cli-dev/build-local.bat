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

docker buildx build -t iwcd-az-cli-dev-u:azure-linux .
