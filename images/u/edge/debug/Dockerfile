# syntax=docker/dockerfile:1
ARG __target_image=iwhicr.azurecr.io/webmethods-edge-runtime:12.0.5.0

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
ARG __wzp_local_uid=1001
ARG __wzp_local_gid=1001
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
    && { getent group ${__wzp_local_gid} >/dev/null 2>&1 \
        || addgroup -g ${__wzp_local_gid} buildgrp; } \
    && { getent passwd ${__wzp_local_uid} >/dev/null 2>&1 \
        || adduser -D -u ${__wzp_local_uid} -G "$(getent group ${__wzp_local_gid} | cut -d: -f1)" builduser; } \
    && mkdir -p /tmp/repo \
    && chown -R ${__wzp_local_uid}:${__wzp_local_gid} /cp \
    && git clone -b ${__zz_pk_repo_tag} --depth 1 \
        --filter=blob:none --sparse ${__zz_pk_repo_url} /tmp/clone \
    && git -C /tmp/clone sparse-checkout set ${__zz_pk_rel_path} ${__zz_mvn_rel_path} \
    && cp -r /tmp/clone/01-code /tmp/repo/ \
    && chown -R ${__wzp_local_uid}:${__wzp_local_gid} /tmp/repo

USER ${__wzp_local_uid}

WORKDIR /tmp/repo/${__zz_mvn_rel_path}
# Note - this needs to match the java version of the target edge image
# -Djava.specification.version overrides the pom property used in <release>
RUN mvn package \
    -Djava.specification.version=21 \
    -Dmaven.compiler.release=21


# ---------------------------------------------------------------------------
# builder – copies the package into the edge image and runs jcode
# ---------------------------------------------------------------------------
FROM ${__target_image} AS builder

ARG __wm_home=/opt/webmethods
ARG __wzp_local_uid=1824
ARG __wzp_local_gid=1824
ARG __pck_name=ZxPipelineLogger
ARG __pck_home=${__wm_home}/IntegrationServer/packages
ARG __zz_pk_rel_path=01-code/is-packages/${__pck_name}

COPY --chown=${__wzp_local_uid}:${__wzp_local_gid} --from=jarbuilder \
    /tmp/repo/${__zz_pk_rel_path}/ \
    ${__pck_home}/${__pck_name}/

USER root

RUN cd ${__pck_home}/../bin \
    && ./jcode.sh make ${__pck_name} \
        > /tmp/jcode.out 2> /tmp/jcode.err; _jcode_rc=$? \
    && echo "--- verifying compiled classes ---" \
    && _src_root="${__pck_home}/${__pck_name}/code/source" \
    && _cls_root="${__pck_home}/${__pck_name}/code/classes" \
    && _missing=0 \
    && for _src in $(find "${_src_root}" -name "*.java"); do \
           _rel="${_src#${_src_root}/}"; \
           _cls="${_cls_root}/${_rel%.java}.class"; \
           if [ ! -f "${_cls}" ]; then \
               echo "MISSING class for: ${_rel}"; \
               _missing=1; \
           else \
               echo "OK: ${_rel%.java}.class"; \
           fi; \
       done \
    && { [ "${_missing}" -eq 0 ] && [ "${_jcode_rc}" -eq 0 ]; } \
    || { echo "=== jcode.sh stdout ==="; cat /tmp/jcode.out; \
         echo "=== jcode.sh stderr ==="; cat /tmp/jcode.err; \
         echo "jcode compilation incomplete (rc=${_jcode_rc}, missing=${_missing})"; exit 1; }


# ---------------------------------------------------------------------------
# Final image
# ---------------------------------------------------------------------------
FROM ${__target_image}

ARG __wm_home=/opt/webmethods
ARG __wzp_local_uid=1001
ARG __wzp_local_gid=1001
ARG __img_user_name=sagadmin
ARG __pck_name=ZxPipelineLogger
ARG __pck_home=${__wm_home}/IntegrationServer/packages

USER root

RUN { getent group ${__wzp_local_gid} >/dev/null 2>&1 \
        || groupmod -g ${__wzp_local_gid} ${__img_user_name}; } \
    && { getent passwd ${__wzp_local_uid} >/dev/null 2>&1 \
        || usermod -u ${__wzp_local_uid} ${__img_user_name}; } \
    && chown -R ${__wzp_local_uid}:${__wzp_local_gid} ${__wm_home}

COPY --chown=${__wzp_local_uid}:${__wzp_local_gid} --from=builder \
    ${__pck_home}/${__pck_name}/ \
    ${__pck_home}/${__pck_name}/

USER ${__wzp_local_uid}
