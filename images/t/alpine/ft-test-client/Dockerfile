ARG __base_image=ft-test-client-s:alpine
FROM ${__base_image}

#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# Provided assets home - where our utility scripts live
ARG __provided_assets_home=/opt/ft-test-client

# Dependency -> posix utils
ARG __iwcd_pu_tag=v0.1.5
ARG __iwcd_base_url=https://raw.githubusercontent.com/ibm-webmethods-continuous-delivery/2l-posix-shell-utils/refs/tags/${__iwcd_pu_tag}
# PU_HOME: where posix-shell-utils code files are cached at build time
ARG __pu_home="${__provided_assets_home}/util/PU_HOME"

# Environment variables consumed by ft-test-client-functions.sh and posix-shell-utils
ENV \
    PU_HOME="${__provided_assets_home}/util/PU_HOME" \
    FTC_PROVIDED_SCRIPTS_HOME="${__provided_assets_home}/scripts" \
    PS1='\u@\h:\w# '

# Create directory structure, download posix-shell-utils code files, copy scripts
RUN mkdir -p "${__provided_assets_home}/scripts" "${__pu_home}/code" \
    && curl --silent --fail ${__iwcd_base_url}/code/1.init.sh  -o "${__pu_home}/code/1.init.sh" \
    && curl --silent --fail ${__iwcd_base_url}/code/2.audit.sh -o "${__pu_home}/code/2.audit.sh" \
    && chmod -R a+rx "${__provided_assets_home}"

COPY ./scripts/ "${__provided_assets_home}/scripts"/

# Make all scripts readable (not executable - they are sourced or invoked via sh)
RUN chmod -R a+r "${__provided_assets_home}"

# No CMD - U-tier will define behavior