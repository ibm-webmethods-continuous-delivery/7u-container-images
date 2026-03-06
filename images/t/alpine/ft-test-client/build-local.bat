@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-ft-test-client-s:alpine' exists
docker image inspect iwcd-ft-test-client-s:alpine >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-ft-test-client-s:alpine' not found. Building it first...
    pushd .
    cd ..\..\..\s\alpine\ft-test-client
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-ft-test-client-s:alpine' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build -t iwcd-ft-test-client-t:alpine .

@REM Made with Bob
