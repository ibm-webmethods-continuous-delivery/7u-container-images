ARG __base_image=cert-manager-t:alpine
FROM ${__base_image}

ARG __gid=1001
ARG __gname=certmgr
ARG __uid=1001
ARG __uname=certmgr

# this folder receives a mount of the main repository
ARG __cmgr_data_folder=/mnt/data/certmgr

# this folder is expected to receive a mount for the user home
ARG __cmgr_user_home=/home/${__uname}

ENV CERT_MGR_USER_HOME=${__cmgr_user_home} \
    CERT_MGR_DATA_FOLDER=${__cmgr_data_folder}

RUN addgroup -g ${__gid} ${__gname} \
    && mkdir -p \
      "${__cmgr_user_home}" \
      "${__cmgr_data_folder}" \
    && adduser -u ${__uid} -G ${__gname} -D -h ${__cmgr_user_home} ${__uname} \
    && rm -rf /tmp/* \
    && chown -R ${__uid}:${__gid} "${__cmgr_data_folder}" /tmp
USER ${__uname}

WORKDIR "${__cmgr_data_folder}"

VOLUME \
  "${__cmgr_user_home}" \
  "${__cmgr_data_folder}" \
  /tmp

# Note: as we are running with a read-only root FS, /tmp needs to have a special regimen and be mounted.
