@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-terraform-s:alpine' exists

docker image inspect iwcd-terraform-s:alpine >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-terraform-s:alpine' not found. Building it first...
    pushd .
    cd ..\..\..\s\alpine\iwcd-terraform
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-terraform-s:alpine' image.
        popd
        exit /b 1
    )
    popd
)

docker buildx build -t iwcd-terraform-u:alpine .
