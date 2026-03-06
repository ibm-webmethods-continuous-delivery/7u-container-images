@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-aio-base-t:alpine' exists

docker image inspect iwcd-aio-base-t:alpine >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-aio-base-t:alpine' not found. Building it first...
    pushd .
    cd ..\..\..\t\alpine\iwcd-aio-base
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-aio-base-t:alpine' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build -t iwcd-aio-base-u:alpine .
