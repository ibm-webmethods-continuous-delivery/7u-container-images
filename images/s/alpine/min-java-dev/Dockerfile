ARG __alpine_tag=3.23
FROM alpine:${__alpine_tag}

#
# Copyright IBM Corp. 2025 - 2025
# SPDX-License-Identifier: Apache-2.0
#

# We do not agree with this hadolint rule for Alpine or any other distro that only works with the latest version of a package.
# hadolint ignore=DL3018
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      curl \
      git \
      lazygit \
      maven \
      neovim \
      neovim-doc \
      openjdk17-jdk \
      ripgrep \
      shellcheck \
      shunit2 \
      yazi

ENV EDITOR=nvim
