ARG __base_image=iwcd-az-cli-dev-s:azure-linux
FROM ${__base_image}

ARG __gid=1001
ARG __gname=iwcd-az-cli-dev
ARG __uid=1001
ARG __uname=iwcd-az-cli-dev

# this folder receives a mount of the main repository
ARG __iwcd_az_cli_dev_workspace_home=/azcli

# this folder is expected to receive a mount for the user home
ARG __iwcd_az_cli_dev_user_home=/home/${__uname}

ENV IWCD_AZ_CLI_DEV_USER_HOME=${__iwcd_az_cli_dev_user_home} \
    IWCD_AZ_CLI_DEV_THIS_REPO_HOME=${__iwcd_az_cli_dev_workspace_home}

RUN groupadd -g ${__gid} ${__gname} \
    && mkdir -p \
      "${__iwcd_az_cli_dev_user_home}" \
      "${__iwcd_az_cli_dev_workspace_home}" \
    && useradd -u ${__uid} -g ${__gid} -l -d ${__iwcd_az_cli_dev_user_home} ${__uname} \
    && rm -rf /tmp/* \
    && chown -R ${__uid}:${__gid} \
      "${__iwcd_az_cli_dev_user_home}" \
      "${__iwcd_az_cli_dev_workspace_home}" \
      /tmp
USER ${__uname}

WORKDIR "${__iwcd_az_cli_dev_workspace_home}"

VOLUME \
  "${__iwcd_az_cli_dev_user_home}" \
  "${__iwcd_az_cli_dev_workspace_home}" \
  /tmp

# Note: as we are running with a read-only root FS, /tmp needs to have a special regimen and be mounted.
