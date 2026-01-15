@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 't-alpine:git-guardian' exists

docker image inspect t-alpine:git-guardian >nul 2>&1
if errorlevel 1 (
    echo Image 't-alpine:git-guardian' not found. Building it first...
    pushd .
    cd ..\..\..\t\alpine\git-guardian
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 't-alpine:git-guardian' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build -t u-alpine:git-guardian .
