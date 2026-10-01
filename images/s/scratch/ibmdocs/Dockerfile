# Stage 1: clone and build static binary for the current platform
FROM alpine:3 AS builder

#
# Copyright IBM Corp. 2025 - 2026
# SPDX-License-Identifier: Apache-2.0
#

RUN apk add --no-cache go musl-dev git ca-certificates

ARG VERSION=v0.0.2
ARG GIT_REPO=https://github.com/ibm-webmethods-continuous-delivery/7u-ibm-doc-fetcher-cli.git

WORKDIR /build

RUN git clone --depth 1 --branch ${VERSION} ${GIT_REPO} .

RUN CGO_ENABLED=0 go build \
    -ldflags "-s -w \
      -X github.com/ibm-webmethods-aftermarket-tools/7u-ibm-doc-fetcher-cli/cmd.version=${VERSION} \
      -X github.com/ibm-webmethods-aftermarket-tools/7u-ibm-doc-fetcher-cli/cmd.buildDate=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
      -X github.com/ibm-webmethods-aftermarket-tools/7u-ibm-doc-fetcher-cli/cmd.gitCommit=$(git rev-parse --short HEAD)" \
    -o ibmdocs \
    ./cmd/ibmdocs

# Verify static linkage
RUN ldd ibmdocs 2>&1 | grep -qE "(statically linked|Not a valid dynamic program|not a dynamic executable)" \
    || (echo "ERROR: binary is not statically linked" && exit 1)

# Stage 2: minimal runtime image
FROM scratch

# CA certificates required for HTTPS to 1.www.s81c.com
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=builder /build/ibmdocs /ibmdocs

ENTRYPOINT ["/ibmdocs"]
