#!/bin/sh
#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#
# Utility function to ensure FTP user exists
# This function can be called from U-tier entrypoint
# Follows XDG Base Directory Specification

# shellcheck disable=SC3043

# Function 01 - consistently create a user to be used in ProFTPd test double server
create_ftp_user(){
  # Params
  # $1 - user name
  # $2 - user id
  # $3 - user group name
  # $4 - user group id
  # $5 - OPTIONAL: password, default Manage01
  # $6 - OPTIONAL: ProFTDPd virtual PASSWD users file, default /etc/proftpd/ftppasswd
  # $7 - OPTIONAL: ProFTDPd virtual groups users file, default /etc/proftpd/fgroup

  if [ "${FTD_DISABLE_SECURITY_DEFAULTS}" = 'true' ]; then
    if [ -z ${5+x} ]; then
      echo "[FATAL] user password MUST be provided!"
      return 1
    fi
  fi

  local _l_error_count=0

  local _l_pass_hash
  _l_pass_hash=$(openssl passwd -1 "${5:-Manage01}")

  mkdir -p "/home/${1}/private" "/home/${1}/shared"

  addgroup -g "${4}" "${3}" || _l_error_count=$((_l_error_count+1))
  adduser  -D -u "${2}" -G "${3}" -H -s /sbin/nologin "${1}" || _l_error_count=$((_l_error_count+1))

  chown -R "${1}":"${2}" "/home/${1}"
  chmod 755  "/home/${1}/shared"
  {
    echo "This is ${1}'s shared folder"
    echo "Other users can only read from here"
  } > "/home/${1}/shared/README.txt"

  printf \
    "%s:%s:%s:%s:Virtual FTP User %s:/home/%s:/sbin/nologin\n" \
    "${1}" "${_l_pass_hash}" \
    "${2}" "${4}" "${1}" "${1}" >> "${6:-/etc/proftpd/ftppasswd}"

  printf \
    "%s:x:%s:%s\n" \
    "${3}" "${4}" "${1}"  >> "${7:-/etc/proftpd/ftpgroup}"

}

# Function 02 - assure ssh host keys
assure_ssh_host_key() {
  # Params
  # $1 - key directory (default: ${HOME}/.ssh)
  # $2 - key file name (default: ftpd_id_25519)
  # Note, inside this, we expect two key files, not encrypted:
  # ssh_host_rsa_key
  # ssh_host_ed25519_key

  if [ "${FTD_DISABLE_SECURITY_DEFAULTS}" = 'true' ]; then
    local _l_error_count=0
    if [ ! -d "${1}" ]; then
      echo "[FATAL] Mandatory server ssh key folder ${1} missing!"
      return 1
    else
      if [ ! -f "${1}/${2}" ]; then
        echo "[FATAL] Mandatory server ssh key file ${1}/${2} missing!"
        return 2
      fi
    fi
  fi

  local _l_ssh_key_dir _l_ssh_key_file
  _l_ssh_key_dir="${1:-${HOME}/.ssh}"
  _l_ssh_key_file="${2:-ftpd_id_25519}"

  # Ensure directory exists
  mkdir -p "${_l_ssh_key_dir}"

  # default is post quantum ed25519
    if [ ! -f "${_l_ssh_key_dir}/${_l_ssh_key_file}" ]; then
      echo "[INFO] SSH host key not found in ${_l_ssh_key_dir}/${_l_ssh_key_dir}"
      echo "[INFO] Generating SSH ed25519 host key..."

      # Generate keys in the ssh config directory
      ssh-keygen -t ed25519 -f "${_l_ssh_key_dir}/${_l_ssh_key_file}" -N "" -q

      echo "[INFO] SSH host ed25519 key generated successfully"
    fi

}

# Function 03 - assure server key and certificate
assure_server_key_and_certificate(){
  # Params
  # $1 - certificate file
  # $2 - private key file

  if [ "${FTD_DISABLE_SECURITY_DEFAULTS}" = 'true' ]; then
    local _l_error_count=0
    if [ ! -f "${1}" ]; then
      echo "[FATAL] Mandatory certificate file ${1} does not exist"
      _l_error_count=$((_l_error_count + 1))
    fi
    if [ ! -f "${2}" ]; then
      echo "[FATAL] Mandatory private key file ${2} does not exist"
      _l_error_count=$((_l_error_count + 1))
    fi

    if [ ${_l_error_count} -ne 0 ]; then
      return 1
    fi
  fi

  if [ ! -f "${1}" ]; then
    echo ">>> WARNING: server certificate does not exist!"
    echo ">>> Generating self-signed TLS certificate …"
    openssl req -new -x509 -days 3650 -nodes \
                -out "${1}" \
                -keyout "${2}" \
                -subj "/CN=ft-test-double/O=test/C=XX"
    chmod 600 "${2}"
  fi
}
