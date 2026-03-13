ARG __base_image=iwcd-aio-base-s:alpine
FROM ${__base_image} AS stage1

# Dependency -> posix utils
ARG __iwcd_pu_tag=v0.1.5
ARG __iwcd_base_url=https://raw.githubusercontent.com/ibm-webmethods-continuous-delivery/2l-posix-shell-utils/refs/tags/${__iwcd_pu_tag}

# Our code
ARG __provided_assets_home=/opt/iwcd-aio
ARG __pu_home="${__provided_assets_home}/util/PU_HOME"

ENV PU_HOME="${__pu_home}"
RUN apk add --no-cache curl \
    && mkdir -p "${__pu_home}/code" \
    && curl ${__iwcd_base_url}/code/1.init.sh -o "${__pu_home}/code/1.init.sh" \
    && curl ${__iwcd_base_url}/code/2.audit.sh -o "${__pu_home}/code/2.audit.sh" \
    && chmod -R a+rx "${__provided_assets_home}"

COPY ./.ashrc "${__provided_assets_home}"/.ashrc
COPY ./scripts/ "${__provided_assets_home}/util"/
COPY ./config/ "${__provided_assets_home}/.config"/

FROM ${__base_image}

ARG __provided_assets_home=/opt/iwcd-aio
ARG __pu_home="${__provided_assets_home}/util/PU_HOME"

ENV \
    ENV="${__provided_assets_home}/.ashrc" \
    IWCD_AIO_PROVIDED_SCRIPTS_HOME="${__provided_assets_home}/util" \
    IWCD_AIO_PROVIDED_CONFIG_HOME="${__provided_assets_home}/.config" \
    PS1='\u@\h:\w# ' \
    PU_HOME="${__pu_home}" \
    XDG_CONFIG_HOME="${__provided_assets_home}/.config"

COPY --from=stage1 ${__provided_assets_home}/ ${__provided_assets_home}/
