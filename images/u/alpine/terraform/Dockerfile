ARG __base_image=iwcd-terraform-s:alpine
FROM ${__base_image}

ARG __gid=1001
ARG __gname=iwcd-tf
ARG __uid=1001
ARG __uname=iwcd-tf

# this folder receives a mount of the main repository
ARG __iwcd_tf_workspace_home=/tf

# this folder is expected to receive a mount for the user home
ARG __iwcd_tf_user_home=/home/${__uname}

ENV IWCD_TF_USER_HOME=${__iwcd_tf_user_home} \
    IWCD_TF_THIS_REPO_HOME=${__iwcd_tf_workspace_home}

RUN addgroup -g ${__gid} ${__gname} \
    && mkdir -p \
      "${__iwcd_tf_user_home}" \
      "${__iwcd_tf_workspace_home}" \
    && adduser -u ${__uid} -G ${__gname} -D -h ${__iwcd_tf_user_home} ${__uname} \
    && rm -rf /tmp/* \
    && chown -R ${__uid}:${__gid} "${__iwcd_tf_workspace_home}" /tmp
USER ${__uname}

WORKDIR "${__iwcd_tf_workspace_home}"

VOLUME \
  "${__iwcd_tf_user_home}" \
  "${__iwcd_tf_workspace_home}" \
  /tmp

# Note: as we are running with a read-only root FS, /tmp needs to have a special regimen and be mounted.
