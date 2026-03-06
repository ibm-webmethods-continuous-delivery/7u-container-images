ARG __alpine_tag=3.23
FROM alpine:${__alpine_tag}

# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# Install certificate management packages
# Principle: Minimum dependencies for lower maintenance and running costs
# openssh is included to provide ssh-keygen for SSH key pair generation

# We do not agree with this hadolint rule for Alpine or any other distro that only works with the latest version of a package.
# hadolint ignore=DL3018
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
        curl \
        openjdk25 \
        openssl \
        openssh
