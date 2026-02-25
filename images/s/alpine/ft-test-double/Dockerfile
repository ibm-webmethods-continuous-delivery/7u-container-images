ARG __alpine_tag=3.23

# Stage 1: Build OQS Provider for Post-Quantum Cryptography
FROM alpine:${__alpine_tag} AS oqs-builder

RUN apk add --no-cache \
        build-base \
        cmake \
        ninja \
        openssl-dev \
        git

# Build liboqs (the library containing the PQ algorithms)
RUN git clone --depth 1 https://github.com/open-quantum-safe/liboqs.git /opt/liboqs && \
    cd /opt/liboqs && \
    mkdir build && cd build && \
    cmake -GNinja -DCMAKE_INSTALL_PREFIX=/usr/local .. && \
    ninja install

# Build oqs-provider (the OpenSSL 3 interface)
RUN git clone --depth 1 https://github.com/open-quantum-safe/oqs-provider.git /opt/oqs-provider && \
    cd /opt/oqs-provider && \
    mkdir build && cd build && \
    cmake -GNinja \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -Dliboqs_DIR=/usr/local/lib64/cmake/liboqs \
        .. && \
    ninja install

# Stage 2: Runtime Image
FROM alpine:${__alpine_tag}

#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# Main purpose is to have proftpd serving all protocols: FTP, FTP/S and SFTP
# Secondary purpose is to have "test spy" tools - will add as needed
# Now includes OQS provider for post-quantum cryptography support
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
        openssh-keygen \
        openssl \
        proftpd \
        proftpd-mod_sftp \
        proftpd-mod_tls

# Copy OQS provider from builder stage
COPY --from=oqs-builder /usr/lib/ossl-modules/oqsprovider.so /usr/lib/ossl-modules/
