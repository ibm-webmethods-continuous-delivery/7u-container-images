ARG __base_image=ft-test-double-s:alpine
FROM ${__base_image}

#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# Provided assets home - where our utility scripts live
ARG __provided_assets_home=/opt/ft-test-double


# XDG Base Directory Specification for non-root containers
# These are relative to the user's home directory and will be set in U-tier
# T-tier provides the defaults that U-tier will use
ENV \
    FTD_DISABLE_SECURITY_DEFAULTS='true' \
    FTD_PROVIDED_SCRIPTS_HOME="${__provided_assets_home}/scripts" \
    PS1='\u@\h:\w# '

# Create directory structure and copy utility scripts
RUN mkdir -p "${__provided_assets_home}/scripts"

COPY ./scripts/ "${__provided_assets_home}/scripts"/

# Make all scripts readable (not executable - they are sourced)
RUN chmod -R a+r "${__provided_assets_home}"
