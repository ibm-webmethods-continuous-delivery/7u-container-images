@echo off
REM SPDX-License-Identifier: Apache-2.0
REM
REM Container Image Builder - Windows Wrapper
REM
REM Usage:
REM   build.bat                              - Build all images
REM   build.bat u/alpine/git-guardian        - Build specific image
REM   build.bat t/alpine/cert-manager        - Build specific image with dependencies
REM   build.bat --scan                       - Build all with scanning
REM   build.bat u/alpine/git-guardian --scan - Build specific with scanning

setlocal

REM Get the directory where this script is located
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

REM Parse arguments
set BUILD_TARGET=all
set ENABLE_SCAN=false

:parse_args
if "%~1"=="" goto :done_parsing
if /i "%~1"=="--scan" (
    set ENABLE_SCAN=true
) else if /i "%~1"=="-s" (
    set ENABLE_SCAN=true
) else (
    set BUILD_TARGET=%~1
)
shift
goto :parse_args

:done_parsing

echo ===================================
echo Container Image Builder
echo ===================================
echo Build Target: %BUILD_TARGET%
echo Scanning: %ENABLE_SCAN%
echo ===================================
echo.

REM Run the build using docker compose
docker compose run --rm -e BUILD_TARGET=%BUILD_TARGET% -e ENABLE_SCAN=%ENABLE_SCAN% 7u-ci-builder

if errorlevel 1 (
    echo.
    echo ===================================
    echo Build FAILED!
    echo ===================================
    exit /b 1
)

echo.
echo ===================================
echo Build completed successfully!
if "%ENABLE_SCAN%"=="true" (
    echo Scan results: %SCRIPT_DIR%scan-results\
)
echo ===================================

endlocal

@REM Made with Bob
