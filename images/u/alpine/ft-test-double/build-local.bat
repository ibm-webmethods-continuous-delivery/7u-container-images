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

docker buildx build -t iwcd-ft-test-double-u:alpine .
