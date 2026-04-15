@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-min-bob-s:alpine' exists

docker image inspect iwcd-min-bob-s:alpine >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-min-bob-s:alpine' not found. Building it first...
    pushd .
    cd ..\..\..\s\alpine\min-bob
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-min-bob-s:alpine' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build -t iwcd-min-bob-u:alpine .
