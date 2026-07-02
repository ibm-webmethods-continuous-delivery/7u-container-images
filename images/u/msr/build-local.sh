#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

docker buildx build \
  --build-arg "__uid=${BUILD_USER_ID:-1001}" \
  -t iwcd-msr:latest .

# Made with Bob
