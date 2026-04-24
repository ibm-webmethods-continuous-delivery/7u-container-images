ARG __alpine_tag=3.23

ARG __alpine_tag=3.23
FROM alpine:${__alpine_tag} AS stage1

ARG __tf_ver=1.14.9
ARG __trivy_ver=v0.70.0
# Fundamental packages
# We do not agree with this hadolint rule for Alpine or any other distro that only works with the latest version of a package.
# hadolint ignore=DL3018,DL4006
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      curl \
      unzip \
    && curl -sSL \
      https://releases.hashicorp.com/terraform/${__tf_ver}/terraform_${__tf_ver}_linux_amd64.zip \
      -o /tmp/tf.zip \
    && unzip /tmp/tf.zip -d /usr/local/bin \
    && curl -sSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | sh

# Add Trivy for security scanning
# hadolint ignore=DL4006
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b /usr/local/bin ${__trivy_ver} /tmp/trivy-install.sh \
  && apk --no-cache upgrade

## Add Hadolint for container building artifacts scanning
ARG __hadolint_version=v2.14.0
ARG __hadolint_cpu_arch=x86_64
RUN curl -sSL "https://github.com/hadolint/hadolint/releases/download/${__hadolint_version}/hadolint-Linux-${__hadolint_cpu_arch}" \
  -o /usr/local/bin/hadolint \
  && chmod +x /usr/local/bin/hadolint

FROM alpine:${__alpine_tag}

# Fundamental packages
# We do not agree with this hadolint rule for Alpine or any other distro that only works with the latest version of a package.
# hadolint ignore=DL3018
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      git \
      icu-data-full \
      lazygit \
      neovim \
      neovim-doc \
      npm \
      ripgrep \
      shellcheck \
      shfmt \
      shunit2 \
      yazi

COPY --from=stage1 /usr/local/bin/ /usr/local/bin/
