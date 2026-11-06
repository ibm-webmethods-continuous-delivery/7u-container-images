# Stage 1: clone and build static binary for the current platform
FROM alpine:3 AS builder

#
# Copyright IBM Corp. 2025 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# We do not agree with this hadolint rule for Alpine or any other distro that only works with the latest version of a package.
# hadolint ignore=DL3018
RUN apk upgrade \
    && apk update \
    && apk add --no-cache go musl-dev git ca-certificates

ARG VERSION=ibmdocs/v0.0.7
ARG GIT_REPO=https://github.com/ibm-webmethods-continuous-delivery/7u-cli-tools.git

WORKDIR /build

RUN git clone --depth 1 --branch ${VERSION} ${GIT_REPO} .

WORKDIR /build/code/ibmdocs

RUN CGO_ENABLED=0 go build \
    -ldflags "-s -w \
      -X github.com/ibm-webmethods-continuous-delivery/7u-cli-tools/code/ibmdocs/cmd.version=${VERSION} \
      -X github.com/ibm-webmethods-continuous-delivery/7u-cli-tools/code/ibmdocs/cmd.buildDate=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
      -X github.com/ibm-webmethods-continuous-delivery/7u-cli-tools/code/ibmdocs/cmd.gitCommit=$(git rev-parse --short HEAD)" \
    -o /build/ibmdocs \
    ./cmd/ibmdocs

# Verify static linkage
# hadolint ignore=DL4006
RUN ldd /build/ibmdocs 2>&1 | grep -qE "(statically linked|Not a valid dynamic program|not a dynamic executable)" \
    || (echo "ERROR: binary is not statically linked" && exit 1)

# Stage 2: minimal runtime image
FROM scratch

# CA certificates required for HTTPS to 1.www.s81c.com
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=builder /build/ibmdocs /ibmdocs
COPY --from=builder /build/code/ibmdocs/util/skills/ibmdocs/SKILL.md /SKILL.md

ENTRYPOINT ["/ibmdocs"]
