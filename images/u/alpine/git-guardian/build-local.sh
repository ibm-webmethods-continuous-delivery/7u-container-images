#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC3043

# Check if the Docker image 'iwcd-git-guardian-t:alpine' exists
if ! docker image inspect iwcd-git-guardian-t:alpine >/dev/null 2>&1; then
  echo "Image 'iwcd-git-guardian-t:alpine' not found. Building it first..."
  current_dir=$(pwd)
  cd ../../../t/alpine/git-guardian || exit 1
  sh build-local.sh
  local l_build_result=$?
  if [ ${l_build_result} -ne 0 ]; then
    echo "Failed to build 'iwcd-git-guardian-t:alpine' image, return code ${l_build_result}"
    cd "$current_dir" || exit 1
    exit 1
  fi
  cd "$current_dir" || exit 1
fi

docker buildx build -t iwcd-git-guardian-u:alpine .

# Made with Bob
