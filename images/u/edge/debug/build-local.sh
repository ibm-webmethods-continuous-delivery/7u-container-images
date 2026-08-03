#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

# Note: explicit linux/amd64 platform due to webMethods product management choices

docker buildx build \
  --build-arg "__wzp_local_uid=${BUILD_USER_ID:-$(id -u)}" \
  --build-arg "__wzp_local_gid=${BUILD_GROUP_ID:-$(id -g)}" \
  --platform linux/amd64 \
  -t iwcd-edge-debug:latest .
