@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-git-guardian-t:alpine' exists

docker image inspect iwcd-git-guardian-t:alpine >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-git-guardian-t:alpine' not found. Building it first...
    pushd .
    cd ..\..\..\t\alpine\git-guardian
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-git-guardian-t:alpine' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build -t iwcd-git-guardian-u:alpine .
