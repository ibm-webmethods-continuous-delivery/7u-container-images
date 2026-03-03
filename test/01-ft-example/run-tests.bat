@echo off
REM FT Test Example - Run All Scenario Combinations
REM Copyright IBM Corp. 2026 - 2026
REM SPDX-License-Identifier: Apache-2.0
REM
REM Starts the full test harness:
REM   - cert-manager:               generates server TLS certs + client SSH key pairs
REM   - ft-test-double-classical:   ProFTPD in classical (pre-quantum) TLS mode
REM   - ft-test-double-pq-hybrid:   ProFTPD in post-quantum hybrid TLS mode
REM   - ft-test-client:             runs all scenario combinations against both doubles
REM
REM Scenario combinations (10 total):
REM   classical  / ftp            classical  / ftps
REM   classical  / ftps-implicit  classical  / sftp / rsa
REM   classical  / sftp / ed25519
REM   pq-hybrid  / ftp            pq-hybrid  / ftps
REM   pq-hybrid  / ftps-implicit  pq-hybrid  / sftp / rsa
REM   pq-hybrid  / sftp / ed25519

setlocal

echo ================================================================================
echo FT Test Example - All Scenario Combinations
echo ================================================================================
echo.
echo Services:
echo   cert-manager               - generates certs and SSH key pairs
echo   ft-test-double-classical   - classical TLS (RSA + ECDHE), RSA SFTP host key
echo   ft-test-double-pq-hybrid   - PQ hybrid TLS (x25519_kyber768), ED25519 SFTP
echo   ft-test-client             - runs 10 scenario combinations
echo.

REM ── Build images (docker-compose uses pre-built images, not build: context) ──
REM Build order: S-tier (base) → T-tier (scripts) → U-tier (runtime config)
echo Building images...

pushd .
cd ..\..\images\t\alpine\ft-test-client
call build-local.bat
if errorlevel 1 (
    echo [ERROR] Failed to build ft-test-client-t:alpine
    popd
    pause
    exit /b 1
)
popd

pushd .
cd ..\..\images\u\alpine\cert-manager
call build-local.bat
if errorlevel 1 (
    echo [ERROR] Failed to build cert-manager-u:alpine
    popd
    pause
    exit /b 1
)
popd

pushd .
cd ..\..\images\u\alpine\ft-test-double
call build-local.bat
if errorlevel 1 (
    echo [ERROR] Failed to build ft-test-double-u:alpine
    popd
    pause
    exit /b 1
)
popd

pushd .
cd ..\..\images\u\alpine\ft-test-client
call build-local.bat
if errorlevel 1 (
    echo [ERROR] Failed to build ft-test-client-u:alpine
    popd
    pause
    exit /b 1
)
popd

echo.
echo Cleaning up previous run...
docker compose down -v

echo.
echo Starting all services...
docker compose up

echo.
echo ================================================================================
echo Test run complete. Check logs above for results.
echo ================================================================================
echo.
echo To view logs:
echo   docker compose logs ft-test-client
echo.
echo To clean up:
echo   docker compose down -v
echo.

pause

@REM Made with Bob