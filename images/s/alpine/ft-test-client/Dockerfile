ARG __alpine_tag=3.23
FROM alpine:${__alpine_tag}

#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# Install FTP/FTPS/SFTP client packages
# We do not agree with this hadolint rule for Alpine or any other distro that only works with the latest version of a package.
# hadolint ignore=DL3018
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
        curl \
        jq \
        lftp \
        netcat-openbsd \
        openssh-client \
        openssl \
        shunit2 \
        sshpass
