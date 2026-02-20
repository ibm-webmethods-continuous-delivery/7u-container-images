ARG __alpine_tag=3.23
FROM alpine:${__alpine_tag}

# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# Install FTP/FTPS/SFTP server packages
# Principle: Minimum dependencies for lower maintenance and running costs
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
        curl \
        openjdk25 \
        openssl
