ARG __alpine_tag=3.24
FROM alpine:${__alpine_tag} AS base

ARG __tf_ver=1.16.3
ARG __trivy_ver=v0.74.0
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
    && curl -sSL https://github.com/terraform-linters/tflint/releases/latest/download/tflint_linux_amd64.zip -o /tmp/tflint.zip \
    && unzip /tmp/tflint.zip -d /tmp/tflint-i/ \
    && install -c -v /tmp/tflint-i/tflint /usr/local/bin/

# Add Trivy for security scanning
# hadolint ignore=DL4006
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b /usr/local/bin ${__trivy_ver} /tmp/trivy-install.sh \
  && apk --no-cache upgrade

FROM alpine:${__alpine_tag}
COPY --from=base /usr/local/bin/ /usr/local/bin/
