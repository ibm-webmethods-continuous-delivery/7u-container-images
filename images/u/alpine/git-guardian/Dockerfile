ARG __base_image=t-alpine:git-guardian
FROM ${__base_image}

ARG __gid=1001
ARG __gname=guardian
ARG __uid=1001
ARG __uname=guardian

# this folder receives a mount of the main repository
ARG __gg_workspace_home=/gg

# this folder is expected to receive a mount for the user home
ARG __gg_user_home=/home/${__uname}

ENV GG_USER_HOME=${__gg_user_home} \
    GG_THIS_REPO_HOME=${__gg_workspace_home}

RUN addgroup -g ${__gid} ${__gname} \
    && mkdir -p \
      "${__gg_user_home}" \
      "${__gg_workspace_home}" \
    && adduser -u ${__uid} -G ${__gname} -D -h ${__gg_user_home} ${__uname} \
    && chown -R ${__uid}:${__gid} "${__gg_workspace_home}" 
USER ${__uname}

RUN git config --global --add safe.directory "${__gg_workspace_home}"

WORKDIR "${__gg_workspace_home}"

VOLUME \
  "${__gg_user_home}" \
  "${__gg_workspace_home}"
