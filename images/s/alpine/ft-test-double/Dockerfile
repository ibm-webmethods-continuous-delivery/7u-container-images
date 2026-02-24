ARG __alpine_tag=3.23
FROM alpine:${__alpine_tag}

#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# Main purpose is to have proftpd serving all protocols: FTP, FTP/S and SFTP
# Secondary purpose is to have "test spy" tools - will add as needed
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
        openssh-keygen \
        openssl \
        proftpd \
        proftpd-mod_sftp \
        proftpd-mod_tls
