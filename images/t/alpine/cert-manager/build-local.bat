@echo off
REM SPDX-License-Identifier: Apache-2.0

REM Check if the Docker image 'iwcd-cert-manager-s:alpine' exists
docker image inspect iwcd-cert-manager-s:alpine >nul 2>&1
if errorlevel 1 (
  echo Image 'iwcd-cert-manager-s:alpine' not found. Building it first...
  pushd .
  cd ..\..\..\s\alpine\cert-manager
  call build-local.bat
  if errorlevel 1 (
    echo Failed to build 'iwcd-cert-manager-s:alpine' image.
    popd
    exit /b 1
  )
  popd
)

docker buildx build -t iwcd-cert-manager-t:alpine .
