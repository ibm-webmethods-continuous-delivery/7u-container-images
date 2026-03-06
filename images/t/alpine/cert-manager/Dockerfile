ARG __base_image=iwcd-cert-manager-s:alpine
FROM ${__base_image}

#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

ARG __cert_mgr_scripts_home=/opt/cert-mgr
ARG __pu_home="${__cert_mgr_scripts_home}/util/PU_HOME"
# Dependency -> posix utils
ARG __iwcd_pu_tag=v0.1.5
ARG __iwcd_base_url=https://raw.githubusercontent.com/ibm-webmethods-continuous-delivery/2l-posix-shell-utils/refs/tags/${__iwcd_pu_tag}

# Environment variables
ENV \
    CERT_MGR_SCRIPTS_HOME=${__cert_mgr_scripts_home} \
    ENV="${__cert_mgr_scripts_home}/.ashrc" \
    PS1='\u@\h:\w# ' \
    PU_HOME="${__pu_home}" \
    PU_SOURCE_TAG="${__iwcd_pu_tag}"


RUN mkdir -p "${PU_HOME}/code" \
    && curl "${__iwcd_base_url}/code/1.init.sh" -o "${PU_HOME}/code/1.init.sh" \
    && curl "${__iwcd_base_url}/code/2.audit.sh" -o "${PU_HOME}/code/2.audit.sh" \
    && curl "${__iwcd_base_url}/code/4.common.sh" -o "${PU_HOME}/code/4.common.sh"

# Copy test scripts
COPY cert-mgmt-functions.sh ${__cert_mgr_scripts_home}/
COPY .ashrc ${__cert_mgr_scripts_home}/.ashrc
