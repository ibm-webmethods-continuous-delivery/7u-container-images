ARG __base_image=s-alpine:git-guardian
FROM ${__base_image}

# Dependency -> posix utils
ARG __iwcd_pu_tag=v0.0.9
ARG __iwcd_base_url=https://raw.githubusercontent.com/ibm-webmethods-continuous-delivery/2l-posix-shell-utils/refs/tags/${__iwcd_pu_tag}
ARG __iwcd_pu_audit_sh_url=${__iwcd_base_url}/code/1.init.sh

# Our code
ARG __provided_assets_home=/opt/guardian
ARG __pu_home="${__provided_assets_home}/util/PU_HOME"

ENV \
    ENV="${__provided_assets_home}/.ashrc" \
    GG_PROVIDED_SCRIPTS_HOME="${__provided_assets_home}/util" \
    PS1='\u@\h:\w# ' \
    PU_HOME="${__pu_home}" \
    PU_SOURCE_TAG="${__iwcd_pu_tag}"

RUN mkdir -p "${PU_HOME}/code" "/usr/share/git-core/templates/hooks" \
    && chmod 755 /usr/share/git-core/templates/hooks \
    && curl ${__iwcd_pu_audit_sh_url} -o "${PU_HOME}/code/1.init.sh" \
    && chmod -R a+rx "${__provided_assets_home}"  \
    && . ${PU_HOME}/code/1.init.sh

COPY ./.ashrc "${__provided_assets_home}"/.ashrc
COPY ./scripts/ "${__provided_assets_home}/util"/
COPY ./scripts/pre-commit /usr/share/git-core/templates/hooks/pre-commit
RUN chmod 755 /usr/share/git-core/templates/hooks/pre-commit \
    && git config --system init.templateDir /usr/share/git-core/templates
