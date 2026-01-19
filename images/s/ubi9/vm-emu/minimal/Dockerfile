ARG __from_image=registry.access.redhat.com/ubi9/ubi-minimal:latest
FROM ${__from_image}

#
# Copyright IBM Corp. 2025 - 2025
# SPDX-License-Identifier: Apache-2.0
#

RUN microdnf -y update &&\
    microdnf -y install \
      findutils \
      gettext \
      gzip \
      less \
      procps \
      shadow-utils \
      tar \
      which \
      &&\
    microdnf clean all &&\
    rm -rf /var/cache/yum
