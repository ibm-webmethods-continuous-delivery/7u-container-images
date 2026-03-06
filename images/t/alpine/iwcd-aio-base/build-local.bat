@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-aio-base-s:alpine' exists
docker image inspect iwcd-aio-base-s:alpine >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-aio-base-s:alpine' not found. Building it first...
    pushd .
    cd ..\..\..\s\alpine\iwcd-aio-base
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-aio-base-s:alpine' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build -t iwcd-aio-base-t:alpine .

@REM Made with Bob
