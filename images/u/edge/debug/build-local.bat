@echo off
REM SPDX-License-Identifier: Apache-2.0

if not defined BUILD_USER_ID set BUILD_USER_ID=1001
if not defined BUILD_GROUP_ID set BUILD_GROUP_ID=1001
docker buildx build ^
  --build-arg "__wzp_local_uid=%BUILD_USER_ID%" ^
  --build-arg "__wzp_local_gid=%BUILD_GROUP_ID%" ^
  -t iwcd-edge-debug:latest .
