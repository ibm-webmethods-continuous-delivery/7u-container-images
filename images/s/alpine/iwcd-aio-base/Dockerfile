ARG __alpine_tag=3.23
FROM alpine:${__alpine_tag}

# Fundamental packages
# We do not agree with this hadolint rule for Alpine or any other distro that only works with the latest version of a package.
# hadolint ignore=DL3018
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      bash \
      curl \
      git \
      icu-data-full \
      lazygit \
      neovim \
      neovim-doc \
      npm \
      ripgrep \
      shellcheck \
      shunit2 \
      yazi


# Add Trivy for security scanning
ARG __trivy_ver=v0.69.3
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b /usr/local/bin ${__trivy_ver} /tmp/trivy-install.sh \
  && apk --no-cache upgrade

## Add Hadolint for container based artifacts scanning
ARG __hadolint_version=v2.14.0
ARG __hadolint_cpu_arch=x86_64
RUN curl -sSL "https://github.com/hadolint/hadolint/releases/download/${__hadolint_version}/hadolint-Linux-${__hadolint_cpu_arch}" \
  -o /usr/local/bin/hadolint \
  && chmod +x /usr/local/bin/hadolint
