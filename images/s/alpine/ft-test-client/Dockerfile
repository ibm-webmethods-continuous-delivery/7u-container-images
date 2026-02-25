ARG __alpine_tag=3.23
FROM alpine:${__alpine_tag}

#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# Install FTP/FTPS/SFTP client packages
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
        curl \
        jq \
        lftp \
        netcat-openbsd \
        openssh-client \
        openssl \
        sshpass \
        shunit2

# Create test directories
RUN mkdir -p \
    /results \
    /tests

WORKDIR /tests

# Default command
CMD ["/bin/sh"]