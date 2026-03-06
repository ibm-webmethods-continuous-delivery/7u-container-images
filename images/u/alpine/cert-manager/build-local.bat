@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-cert-manager-t:alpine' exists

docker image inspect iwcd-cert-manager-t:alpine >nul 2>&1
if errorlevel 1 (
  echo Image 'iwcd-cert-manager-t:alpine' not found. Building it first...
  pushd .
  cd ..\..\..\t\alpine\cert-manager
  call build-local.bat
  if errorlevel 1 (
    echo Failed to build 'iwcd-cert-manager-t:alpine' image.
    popd
    exit /b 1
  )
  popd
)

docker buildx build -t iwcd-cert-manager-u:alpine .
