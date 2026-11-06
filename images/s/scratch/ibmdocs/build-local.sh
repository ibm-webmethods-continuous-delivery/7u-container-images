#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

_no_cache_flag=""
if [ "${NO_CACHE:-false}" = "true" ]; then _no_cache_flag="--no-cache"; fi

# shellcheck disable=SC2086
docker buildx build $_no_cache_flag -t iwcd-ibmdocs-s:scratch .

# Made with Bob
