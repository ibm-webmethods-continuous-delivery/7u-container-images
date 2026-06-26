ARG __edge_image=iwhicr.azurecr.io/webmethods-edge-runtime:12.0.2

FROM ibmwebmethods.azurecr.io/webmethods-microservicesruntime:11.1.0.11 AS jarsource


FROM alpine:3.23 AS jarbuilder

ARG __pck_name=ZxPipelineLogger
ARG __zz_pk_rel_path=01-code/is-packages/${__pck_name}
ARG __zz_mvn_rel_path=01-code/java/2l-wz-pipelinelogger
ARG __zz_pk_repo_url=https://github.com/ibm-webmethods-continuous-delivery/2l-wz-pack.git
ARG __zz_pk_repo_tag=main

ENV WZP_IS_JARS_DIR=/cp
ENV WZP_WORKSPACE=/tmp/zz-pk-repo-2

RUN mkdir -p /cp /tmp/zz-pk-repo-2

COPY --from=jarsource /opt/softwareag/common/lib/wm-isclient.jar /cp/
COPY --from=jarsource /opt/softwareag/IntegrationServer/lib/wm-isserver.jar /cp/
COPY --from=jarsource /opt/softwareag/IntegrationServer/lib/jars/jackson*.jar /cp/
COPY --from=jarsource /opt/softwareag/common/lib/ext/jackson*.jar /cp/

# We do not agree with this hadolint rule for Alpine or any other distro that only works with the latest version of a package.
# hadolint ignore=DL3018,DL4006
RUN apk --no-cache update \
    && apk --no-cache add curl git maven openjdk17-jdk \
    && git clone -b ${__zz_pk_repo_tag} --depth 1 \
        --filter=blob:none --sparse ${__zz_pk_repo_url} /tmp/zz-pk-repo
WORKDIR /tmp/zz-pk-repo
RUN git sparse-checkout set ${__zz_pk_rel_path} \
    && cp -r ./01-code /tmp/zz-pk-repo-2/ \
    && git sparse-checkout set ${__zz_mvn_rel_path} \
    && cp -r ./01-code /tmp/zz-pk-repo-2/
WORKDIR /tmp/zz-pk-repo-2/${__zz_mvn_rel_path}
RUN mvn package

RUN tree /tmp/


FROM ${__edge_image} AS builder

ARG __pck_home=/opt/webmethods/IntegrationServer/packages
ARG __pck_name=ZxPipelineLogger
ARG __zz_pk_rel_path=01-code/is-packages/${__pck_name}

COPY --chown=1724:0 --from=jarbuilder \
    /tmp/zz-pk-repo-2/${__zz_pk_rel_path}/ \
    ${__pck_home}/${__pck_name}/

RUN cd ${__pck_home}/../bin \
    && ./jcode.sh make ${__pck_name}


FROM ${__edge_image}

ARG __pck_home=/opt/webmethods/IntegrationServer/packages
ARG __pck_name=ZxPipelineLogger

ARG __new_user_id=1001
ARG __new_user_id=1001
ARG __img_user_name=sagadmin

ARG __products_home=/opt/webmethods

USER root

RUN usermod -u ${__new_user_id} ${__img_user_name}

COPY --chown=${__new_user_id}:0 --from=builder \
    ${__pck_home}/${__pck_name}/ \
    ${__pck_home}/${__pck_name}/

USER ${__img_user_name}
