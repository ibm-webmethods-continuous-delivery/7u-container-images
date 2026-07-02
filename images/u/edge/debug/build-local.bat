@echo off
REM SPDX-License-Identifier: Apache-2.0

if not defined BUILD_USER_ID set BUILD_USER_ID=1001
docker buildx build ^
  --build-arg "__uid=%BUILD_USER_ID%" ^
  -t iwcd-edge-debug:latest .
