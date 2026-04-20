ARG __alpine_tag=3.23
FROM alpine:${__alpine_tag} AS base

ARG __tf_ver=1.14.8
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

FROM alpine:${__alpine_tag}
COPY --from=base /usr/local/bin/ /usr/local/bin/
