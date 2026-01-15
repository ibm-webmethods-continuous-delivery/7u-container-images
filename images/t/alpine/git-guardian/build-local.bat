@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 's-alpine:git-guardian' exists
docker image inspect s-alpine:git-guardian >nul 2>&1
if errorlevel 1 (
    echo Image 's-alpine:git-guardian' not found. Building it first...
    pushd .
    cd ..\..\..\s\alpine\git-guardian
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 's-alpine:git-guardian' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build -t t-alpine:git-guardian .

@REM Made with Bob
