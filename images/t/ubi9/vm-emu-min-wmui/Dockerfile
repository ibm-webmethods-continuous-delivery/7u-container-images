ARG __from_img=vm-emu-min-pu-t:ubi9
FROM ${__from_img}

ARG __iwcd_wmui_tag=v0.0.2
ARG __iwcd_wmui_base_url=https://raw.githubusercontent.com/ibm-webmethods-continuous-delivery/2l-unattended-installation-templates/refs/tags/${__iwcd_wmui_tag}
ARG __iwcd_wmui_scripts_sha256=d5558cd419c8d46bdc958064cb97f963d1ea793866414c025906ec15033512ed

ARG __iwcd_wmui_home=/opt/iwcd/wmui

ENV WMUI_HOME=${__iwcd_wmui_home} \
    WMUI_SOURCE_TAG=${__iwcd_wmui_tag}

RUN . /opt/iwcd/pu/code/1.init.sh \
  && . /opt/iwcd/pu/code/3.ingester.sh \
  && mkdir -p "${__iwcd_wmui_home}/01.scripts" \
  && pu_assure_public_file \
    "${__iwcd_wmui_base_url}/01.scripts/wmui-functions.sh" \
    "${__iwcd_wmui_home}/01.scripts/wmui-functions.sh" \
    "${__iwcd_wmui_scripts_sha256}"
