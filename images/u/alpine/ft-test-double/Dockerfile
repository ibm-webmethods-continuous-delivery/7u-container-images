ARG __base_image=ft-test-double-t:alpine
FROM ${__base_image}

#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# ProFTPd user (for running the server)
ARG __ftpd_user_id=1001
ARG __ftpd_user_name=ftpd
ARG __ftpd_group_gid=2001
ARG __ftpd_group_name=ftpdgrp

# Test users (for file transfer operations)
ARG __ft_test_user01_uid=2001
ARG __ft_test_user01_name=ftuser01
ARG __ft_test_group01_gid=2001
ARG __ft_test_group01_name=ftuser01grp
ARG __ft_test_user01_pass=Manage01

ARG __ft_test_user02_uid=2002
ARG __ft_test_user02_name=ftuser02
ARG __ft_test_group02_gid=2002
ARG __ft_test_group02_name=ftuser02grp
ARG __ft_test_user02_pass=Manage02

ARG __ftpd_config_folder=/etc/proftpd
ARG __ftpd_config_file=${__ftpd_config_folder}/proftpd.conf
ARG __ftpd_ssh_config_folder=${__ftpd_config_folder}/.ssh
ARG __ftpd_ssl_config_folder=${__ftpd_config_folder}/.ssl
ARG __ftpd_log_folder=/var/log/proftpd


# Create system directories for configuration and logs
# Using standard FHS (Filesystem Hierarchy Standard) paths for root execution
RUN mkdir -p \
      "${__ftpd_ssh_config_folder}" \
      "${__ftpd_ssl_config_folder}" \
      "${__ftpd_log_folder}" \
    && touch "${__ftpd_config_file}" \
    && . ${FTD_PROVIDED_SCRIPTS_HOME}/ft-test-double-functions.sh \
    && addgroup -g "${__ftpd_group_gid}" "${__ftpd_group_name}" \
    && adduser -D -u "${__ftpd_user_id}" \
      -G "${__ftpd_group_name}" -H -s /sbin/nologin \
      "${__ftpd_user_name}" \
    && assure_server_key_and_certificate \
      "${__ftpd_ssl_config_folder}/server.cer" \
      "${__ftpd_ssl_config_folder}/server.key" \
    && assure_ssh_host_keys "${__ftpd_ssh_config_folder}" \
    && create_ftp_user \
      "${__ft_test_user01_name}" \
      "${__ft_test_user01_uid}" \
      "${__ft_test_group01_name}" \
      "${__ft_test_group01_gid}" \
      "${__ft_test_user01_pass}" \
    && create_ftp_user \
      "${__ft_test_user02_name}" \
      "${__ft_test_user02_uid}" \
      "${__ft_test_group02_name}" \
      "${__ft_test_group02_gid}" \
      "${__ft_test_user02_pass}" \
    chown -R "${__ftpd_user_id}":"${__ftpd_group_gid}" \
      "${__ftpd_config_folder}" "${__ftpd_log_folder}"

VOLUME \
      "${__ftpd_config_file}" \
      "${__ftpd_log_folder}" \
      "${__ftpd_ssh_config_folder}" \
      "${__ftpd_ssl_config_folder}"

ENTRYPOINT exec proftpd --nodaemon --config ${__ftpd_config_file}
