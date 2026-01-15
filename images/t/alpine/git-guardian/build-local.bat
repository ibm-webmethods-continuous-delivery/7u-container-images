@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'git-guardian-s:alpine' exists
docker image inspect git-guardian-s:alpine >nul 2>&1
if errorlevel 1 (
    echo Image 'git-guardian-s:alpine' not found. Building it first...
    pushd .
    cd ..\..\..\s\alpine\git-guardian
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'git-guardian-s:alpine' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build -t git-guardian-t:alpine .

@REM Made with Bob
