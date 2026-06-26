@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-edge-debug:latest' exists
docker image inspect iwcd-edge-debug:latest >nul 2>&1
if errorlevel 1 (
    echo Image 'iwcd-edge-debug:latest' not found. Building it first...
    pushd .
    cd ..\debug
    call build-local.bat
    if errorlevel 1 (
        echo Failed to build 'iwcd-edge-debug:latest' image.
        popd
        exit /b 1
    )
    popd
)

REM Load WPM_TOKEN from set-env.bat if not already set in the environment
if "%WPM_TOKEN%"=="" call set-env.bat

REM Fail early rather than passing an empty secret into the build
if "%WPM_TOKEN%"=="" (
    echo ERROR: WPM_TOKEN is not set. Set it in your environment or in set-env.bat.
    exit /b 1
)

REM --secret passes the token only as a tmpfs mount; it is never stored in any image layer.
docker buildx build --secret id=wpm_token,env=WPM_TOKEN -t iwcd-edge-debug-jdbc:latest .
