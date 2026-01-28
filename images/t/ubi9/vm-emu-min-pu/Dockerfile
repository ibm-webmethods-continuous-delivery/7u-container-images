ARG __from_img=vm-emu-minimal-s:ubi9
FROM ${__from_img}

ARG __iwcd_pu_tag=v0.1.3
ARG __iwcd_pu_base_url=https://raw.githubusercontent.com/ibm-webmethods-continuous-delivery/2l-posix-shell-utils/refs/tags/${__iwcd_pu_tag}

ARG __iwcd_pu_home=/opt/iwcd/pu

ENV PU_HOME=${__iwcd_pu_home} \
    PU_SOURCE_TAG=${__iwcd_pu_tag}

RUN mkdir -p ${__iwcd_pu_home}/code \
  && curl ${__iwcd_pu_base_url}/code/1.init.sh -o "${__iwcd_pu_home}/code/1.init.sh" \
  && curl ${__iwcd_pu_base_url}/code/2.audit.sh -o "${__iwcd_pu_home}/code/2.audit.sh" \
  && . "${__iwcd_pu_home}/code/1.init.sh" \
  && pu_init_hunt_for_pu_file "code" "3.ingester.sh" \
  && pu_init_hunt_for_pu_file "code" "4.common.sh" \
  && pu_init_hunt_for_pu_file "code" "5.network.sh" \
  && pu_init_hunt_for_pu_file "code" "6.string.sh" \
  && pu_init_hunt_for_pu_file "code" "7.data.sh"
