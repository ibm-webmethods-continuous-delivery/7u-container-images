ARG __base_image=iwcd-min-bob-s:alpine
FROM ${__base_image}

ARG __gid=1001
ARG __gname=bob-user
ARG __uid=1001
ARG __uname=bob-user

# this folder receives a mount of the main repository
ARG __bob_workspace_home=/bob-workspace

# this folder is expected to receive a mount for the user home
ARG __bob_user_home=/home/${__uname}

ENV BOB_USER_HOME=${__bob_user_home} \
    BOB_THIS_REPO_HOME=${__bob_workspace_home}

RUN addgroup -g ${__gid} ${__gname} \
    && mkdir -p \
      "${__bob_user_home}" \
      "${__bob_workspace_home}" \
    && adduser -u ${__uid} -G ${__gname} -D -h ${__bob_user_home} ${__uname} \
    && rm -rf /tmp/* \
    && chown -R ${__uid}:${__gid} "${__bob_workspace_home}" /tmp
USER ${__uname}

WORKDIR "${__bob_workspace_home}"

VOLUME \
  "${__bob_user_home}" \
  "${__bob_workspace_home}" \
  /tmp

# Note: as we are running with a read-only root FS, /tmp needs to have a special regimen and be mounted.
