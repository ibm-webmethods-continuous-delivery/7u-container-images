ARG __base_image=iwcd-aio-base-t:alpine
FROM ${__base_image}

ARG __gid=1001
ARG __gname=iwcd-aio
ARG __uid=1001
ARG __uname=iwcd-aio

# this folder receives a mount of the main repository
ARG __iwcd_aio_workspace_home=/aio

# this folder is expected to receive a mount for the user home
ARG __iwcd_aio_user_home=/home/${__uname}

ENV IWCD_AIO_USER_HOME=${__iwcd_aio_user_home} \
    IWCD_AIO_THIS_REPO_HOME=${__iwcd_aio_workspace_home}

RUN addgroup -g ${__gid} ${__gname} \
    && mkdir -p \
      "${__iwcd_aio_user_home}" \
      "${__iwcd_aio_workspace_home}" \
    && adduser -u ${__uid} -G ${__gname} -D -h ${__iwcd_aio_user_home} ${__uname} \
    && rm -rf /tmp/* \
    && chown -R ${__uid}:${__gid} "${__iwcd_aio_workspace_home}" /tmp
USER ${__uname}

RUN git config --global --add safe.directory "${__iwcd_aio_workspace_home}"

WORKDIR "${__iwcd_aio_workspace_home}"

VOLUME \
  "${__iwcd_aio_user_home}" \
  "${__iwcd_aio_workspace_home}" \
  /tmp

# Note: as we are running with a read-only root FS, /tmp needs to have a special regimen and be mounted.
