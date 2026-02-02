ARG __from_image=vm-emu-min-pu-t:ubi9
FROM ${__from_image}

#
# Copyright IBM Corp. 2025 - 2025
# SPDX-License-Identifier: Apache-2.0
#

# Layer 2 - this may vary according to the context in this framework
ARG __user_name=webmethods
ARG __user_id=1001
ARG __group_name=webmethods
ARG __group_id=1001
ARG __user_home=/home/${__user_name}

# Usually for testing purposes we would declare these folders as volumes
ARG __audit_home_dir=/var/webmethods/audit
ARG __install_dir=/opt/webmethods
ARG __upd_mgr_home_dir=/opt/wm-umgr

# Intention is to mount the WMUI from development workspace here
ARG __wmui_home_dir=/opt/iwcd/wmui

# Expect artifacts to be provided in a mounted volume
ARG __artifacts_home_dir=/mnt/artifacts
# Usually these are also volumes, expected to be bind mounted
ARG __script_dir=/mnt/scripts

ENV \
  IWCD_VM_EMU_ARTIFACTS_HOME=${__artifacts_home_dir} \
  IWCD_VM_EMU_INSTALL_DIR=${__install_dir} \
  IWCD_VM_EMU_LOCAL_SCRIPTS_HOME=${__script_dir} \
  IWCD_VM_EMU_UPD_MGR_HOME=${__upd_mgr_home_dir} \
  IWCD_VM_EMU_USER_HOME=${__user_home} \
  PU_AUDIT_BASE_DIR=${__audit_home_dir} \
  WMUI_HOME=${__wmui_home_dir}

RUN /usr/sbin/groupadd -r -g ${__group_id} ${__group_name} &&\
    /usr/sbin/useradd -r -u ${__user_id} -m -d ${__user_home} -g ${__group_name} ${__user_name} &&\
    mkdir -p \
      "${__artifacts_home_dir}" \
      "${__audit_home_dir}" \
      "${__install_dir}" \
      "${__script_dir}" \
      "${__upd_mgr_home_dir}" \
      "${__wmui_home_dir}" &&\
    chown -R ${__user_name}:${__group_name} \
      "${__artifacts_home_dir}" \
      "${__audit_home_dir}" \
      "${__install_dir}" \
      "${__script_dir}" \
      "${__upd_mgr_home_dir}" \
      "${__wmui_home_dir}" \
      /tmp/*

USER ${__user_name}

VOLUME \
  "${__artifacts_home_dir}" \
  "${__audit_home_dir}" \
  "${__install_dir}" \
  "${__script_dir}" \
  "${__upd_mgr_home_dir}" \
  "${__user_home}" \
  "${__wmui_home_dir}"
