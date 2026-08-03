# syntax=docker/dockerfile:1
ARG __target_image=iwhicr.azurecr.io/webmethods-edge-runtime:12.0.3

FROM ${__target_image} AS jarsource

# ---------------------------------------------------------------------------
# jarbuilder – clones the required sources and compiles the JARs with Maven
#
# __wm_home differs by image version:
#   10.x / 11.x  ->  /opt/softwareag
#   12.x         ->  /opt/webmethods
# ---------------------------------------------------------------------------
FROM alpine:3.24 AS jarbuilder

ARG __wm_home=/opt/webmethods
ARG __local_uid=1001
ARG __local_gid=1001
ARG __pck_name=ZxPipelineLogger
ARG __zz_pk_rel_path=01-code/is-packages/${__pck_name}
ARG __zz_mvn_rel_path=01-code/java/2l-wz-pipelinelogger
ARG __zz_pk_repo_url=https://github.com/ibm-webmethods-continuous-delivery/2l-wz-pack.git
ARG __zz_pk_repo_tag=main

ENV WZP_IS_JARS_DIR=/cp
ENV WZP_WORKSPACE=/tmp/repo

COPY --from=jarsource ${__wm_home}/common/lib/wm-isclient.jar                  /cp/
COPY --from=jarsource ${__wm_home}/IntegrationServer/lib/wm-isserver.jar       /cp/
COPY --from=jarsource ${__wm_home}/IntegrationServer/lib/jars/jackson*.jar     /cp/
COPY --from=jarsource ${__wm_home}/common/lib/ext/jackson*.jar                 /cp/

# hadolint ignore=DL3018
RUN apk --no-cache add git maven \
    && { getent group ${__local_gid} >/dev/null 2>&1 \
        || addgroup -g ${__local_gid} buildgrp; } \
    && { getent passwd ${__local_uid} >/dev/null 2>&1 \
        || adduser -D -u ${__local_uid} -G "$(getent group ${__local_gid} | cut -d: -f1)" builduser; } \
    && mkdir -p /tmp/repo \
    && chown -R ${__local_uid}:${__local_gid} /cp \
    && git clone -b ${__zz_pk_repo_tag} --depth 1 \
        --filter=blob:none --sparse ${__zz_pk_repo_url} /tmp/clone \
    && git -C /tmp/clone sparse-checkout set ${__zz_pk_rel_path} ${__zz_mvn_rel_path} \
    && cp -r /tmp/clone/01-code /tmp/repo/ \
    && chown -R ${__local_uid}:${__local_gid} /tmp/repo

USER ${__local_uid}

WORKDIR /tmp/repo/${__zz_mvn_rel_path}
RUN mvn package


# ---------------------------------------------------------------------------
# builder – copies the package into the edge image and runs jcode
# ---------------------------------------------------------------------------
FROM ${__target_image} AS builder

ARG __wm_home=/opt/webmethods
ARG __local_uid=1001
ARG __local_gid=1001
ARG __pck_name=ZxPipelineLogger
ARG __pck_home=${__wm_home}/IntegrationServer/packages
ARG __zz_pk_rel_path=01-code/is-packages/${__pck_name}

COPY --chown=${__local_uid}:${__local_gid} --from=jarbuilder \
    /tmp/repo/${__zz_pk_rel_path}/ \
    ${__pck_home}/${__pck_name}/

RUN cd ${__pck_home}/../bin \
    && ./jcode.sh make ${__pck_name}


# ---------------------------------------------------------------------------
# Final image
# ---------------------------------------------------------------------------
FROM ${__target_image}

ARG __wm_home=/opt/webmethods
ARG __local_uid=1001
ARG __local_gid=1001
ARG __img_user_name=sagadmin
ARG __pck_name=ZxPipelineLogger
ARG __pck_home=${__wm_home}/IntegrationServer/packages

USER root

RUN { getent group ${__local_gid} >/dev/null 2>&1 \
        || groupmod -g ${__local_gid} ${__img_user_name}; } \
    && { getent passwd ${__local_uid} >/dev/null 2>&1 \
        || usermod -u ${__local_uid} ${__img_user_name}; } \
    && chown -R ${__local_uid}:${__local_gid} ${__wm_home}

COPY --chown=${__local_uid}:${__local_gid} --from=builder \
    ${__pck_home}/${__pck_name}/ \
    ${__pck_home}/${__pck_name}/

USER ${__local_uid}
