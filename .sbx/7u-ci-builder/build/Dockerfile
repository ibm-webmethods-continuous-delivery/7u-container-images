ARG __alpine_tag=3.23
FROM alpine:${__alpine_tag}

# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# Install certificate management packages
# Principle: Minimum dependencies for lower maintenance and running costs
# openssh is included to provide ssh-keygen for SSH key pair generation
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
        curl \
        docker-cli \
        docker-cli-buildx \
        jq

# Add Trivy for security scanning
ARG __trivy_ver=v0.70.0
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b /usr/local/bin ${__trivy_ver} /tmp/trivy-install.sh \
  && apk --no-cache upgrade

## Add Hadolint for container based artifacts scanning
ARG __hadolint_version=v2.14.0
ARG __hadolint_cpu_arch=x86_64
RUN curl -sSL "https://github.com/hadolint/hadolint/releases/download/${__hadolint_version}/hadolint-Linux-${__hadolint_cpu_arch}" \
  -o /usr/local/bin/hadolint \
  && chmod +x /usr/local/bin/hadolint