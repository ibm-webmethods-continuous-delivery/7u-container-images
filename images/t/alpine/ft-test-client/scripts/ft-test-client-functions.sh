#!/bin/sh
#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#
# FTP Test Client Function Library
# Provides reusable functions for FTP/FTPS/SFTP testing scenarios.
#
# Key type selection (FTC_KEY_TYPE):
#   rsa      - pre-quantum RSA keys
#   ed25519  - post-quantum Ed25519 keys
#   (extensible: add more types in the future without changing callers)
#
# Protocol selection (FTC_PROTOCOL):
#   ftp           - plain FTP (port 21)
#   ftps          - FTPS explicit TLS / FTPES (port 21, upgrades via AUTH TLS)
#   ftps-implicit - FTPS implicit TLS (port 990, TLS from first byte)
#   sftp          - SSH File Transfer Protocol (port 22)
#
# FTPS explicit vs implicit:
#   Explicit (ftps):  client connects on port 21 as plain FTP, then issues
#                     AUTH TLS to upgrade the control channel.
#                     lftp: ftp:// scheme + set ftp:ssl-force yes
#   Implicit (ftps-implicit): TLS is established immediately on connect,
#                     typically on port 990. No plain-text negotiation.
#                     lftp: ftps:// scheme + set ftp:ssl-force yes
#                           + set ftp:ssl-protect-data yes
#
# Transfer mode (FTC_TRANSFER_MODE):
#   binary - binary transfer mode (default)
#   text   - ASCII/text transfer mode

# shellcheck disable=SC3043

# ═══════════════════════════════════════════════════════════════════════════
# PU_HOME bootstrap - source posix-shell-utils if not already loaded
# ═══════════════════════════════════════════════════════════════════════════

_ftc_bootstrap_pu() {
  if [ -z "${PU_HOME}" ]; then
    echo "[FATAL] PU_HOME is not set. Cannot bootstrap posix-shell-utils." >&2
    return 1
  fi
  if ! type pu_log_i > /dev/null 2>&1; then
    # shellcheck source=/dev/null
    . "${PU_HOME}/code/1.init.sh" || return 1
  fi
}

_ftc_bootstrap_pu || exit 1

# ═══════════════════════════════════════════════════════════════════════════
# Configuration defaults (override via environment variables)
# ═══════════════════════════════════════════════════════════════════════════

# Key type: rsa | ed25519 | <future-type>
FTC_KEY_TYPE="${FTC_KEY_TYPE:-rsa}"

# Protocol: ftp | ftps | ftps-implicit | sftp
FTC_PROTOCOL="${FTC_PROTOCOL:-sftp}"

# Transfer mode: binary | text
FTC_TRANSFER_MODE="${FTC_TRANSFER_MODE:-binary}"

# Server connection parameters
FTC_HOST="${FTC_HOST:-ft-test-double}"
FTC_PORT="${FTC_PORT:-}" # empty = protocol default

# Primary user credentials
FTC_USER="${FTC_USER:-ftuser01}"
FTC_PASS="${FTC_PASS:-Manage01}"

# Read-only / secondary user credentials (scenario 2)
FTC_RO_USER="${FTC_RO_USER:-ftuser02}"
FTC_RO_PASS="${FTC_RO_PASS:-Manage01}"

# SSH key directories (one per key type)
FTC_SSH_KEYS_HOME="${FTC_SSH_KEYS_HOME:-/run/secrets/ft-test-client}"
# Key file name within FTC_SSH_KEYS_HOME/<key-type>/
FTC_SSH_KEY_FILENAME="${FTC_SSH_KEY_FILENAME:-id_client}"

# Remote upload directory (primary user)
FTC_REMOTE_UPLOAD_DIR="${FTC_REMOTE_UPLOAD_DIR:-private}"

# Remote read-only directory visible to secondary user
# Typically the primary user's shared folder
FTC_REMOTE_RO_DIR="${FTC_REMOTE_RO_DIR:-/home/${FTC_USER}/shared}"

# Working directory for local temp files
FTC_WORK_DIR="${FTC_WORK_DIR:-/tmp/ftc-work}"

# ═══════════════════════════════════════════════════════════════════════════
# Internal helpers
# ═══════════════════════════════════════════════════════════════════════════

# Resolve effective port for the chosen protocol
# ftps-implicit defaults to 990 (IANA assigned for implicit FTPS)
_ftc_effective_port() {
  if [ -n "${FTC_PORT}" ]; then
    echo "${FTC_PORT}"
    return
  fi
  case "${FTC_PROTOCOL}" in
    ftp) echo "21" ;;
    ftps) echo "21" ;;
    ftps-implicit) echo "990" ;;
    sftp) echo "22" ;;
    *) echo "21" ;;
  esac
}

# Resolve SSH identity file for the chosen key type
_ftc_ssh_identity_file() {
  echo "${FTC_SSH_KEYS_HOME}/${FTC_KEY_TYPE}/${FTC_SSH_KEY_FILENAME}"
}

# Build lftp transfer mode setting
_ftc_lftp_mode_flag() {
  case "${FTC_TRANSFER_MODE}" in
    text) echo "set ftp:type ascii;" ;;
    binary) echo "set ftp:type binary;" ;;
    *) echo "set ftp:type binary;" ;;
  esac
}

# Build lftp SSL/TLS settings for the chosen protocol.
#
# ftp:           no TLS
# ftps:          explicit TLS - connect on plain FTP port, upgrade via AUTH TLS
#                  ftp:// URL scheme; ssl-force yes; ssl-protect-data yes
# ftps-implicit: implicit TLS - TLS from first byte on port 990
#                  ftps:// URL scheme; ssl-force yes; ssl-protect-data yes
#
# Returns two values via stdout, separated by a space:
#   <lftp-settings-string> <url-scheme>
# Callers split on the last token for the scheme and use the rest as settings.
#
# We use a single function that sets two variables instead of stdout splitting
# to avoid subshell overhead and quoting complexity:
#   _FTC_LFTP_SSL_SETTINGS  - lftp set commands (semicolon-terminated)
#   _FTC_LFTP_URL_SCHEME    - "ftp" or "ftps"
_ftc_lftp_ssl_init() {
  case "${FTC_PROTOCOL}" in
    ftp)
      _FTC_LFTP_SSL_SETTINGS="set ftp:ssl-allow no;"
      _FTC_LFTP_URL_SCHEME="ftp"
      ;;
    ftps)
      # Explicit TLS: connect as plain FTP, upgrade control channel via AUTH TLS
      _FTC_LFTP_SSL_SETTINGS="set ftp:ssl-force yes; set ftp:ssl-protect-data yes; set ssl:verify-certificate no;"
      _FTC_LFTP_URL_SCHEME="ftp"
      ;;
    ftps-implicit)
      # Implicit TLS: TLS wraps the entire connection from the start
      # lftp uses the ftps:// scheme to signal implicit mode
      _FTC_LFTP_SSL_SETTINGS="set ftp:ssl-force yes; set ftp:ssl-protect-data yes; set ftp:ssl-protect-list yes; set ssl:verify-certificate no; set ssl:check-hostname no;"
      _FTC_LFTP_URL_SCHEME="ftps"
      ;;
    *)
      _FTC_LFTP_SSL_SETTINGS="set ftp:ssl-allow no;"
      _FTC_LFTP_URL_SCHEME="ftp"
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════
# Connectivity check
# ═══════════════════════════════════════════════════════════════════════════

# Check if the server port is reachable
# Returns 0 if reachable, 1 otherwise
ftc_check_port() {
  local _l_host="${1:-${FTC_HOST}}"
  local _l_port="${2:-$(_ftc_effective_port)}"

  pu_log_i "FTC| Checking connectivity to ${_l_host}:${_l_port} ..."
  if nc -z -w 5 "${_l_host}" "${_l_port}" 2> /dev/null; then
    pu_log_i "FTC| Port ${_l_host}:${_l_port} is reachable."
    return 0
  else
    pu_log_e "FTC| Port ${_l_host}:${_l_port} is NOT reachable."
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# File preparation
# ═══════════════════════════════════════════════════════════════════════════

# Prepare a random binary file of given size (default 4096 bytes)
# $1 - destination file path
# $2 - size in bytes (optional, default 4096)
ftc_prepare_random_file() {
  local _l_dest="${1}"
  local _l_size="${2:-4096}"

  mkdir -p "$(dirname "${_l_dest}")"
  dd if=/dev/urandom of="${_l_dest}" bs="${_l_size}" count=1 2> /dev/null
  pu_log_i "FTC| Prepared random file: ${_l_dest} (${_l_size} bytes)"
}

# Compute sha256sum of a file; prints the hex digest only
# $1 - file path
ftc_sha256() {
  sha256sum "${1}" | awk '{print $1}'
}

# ═══════════════════════════════════════════════════════════════════════════
# Remote state audit helpers (pwd + ls)
# ═══════════════════════════════════════════════════════════════════════════

# Audit remote state via FTP/FTPS/FTPS-implicit using lftp
# $1 - remote directory to list (optional, default: .)
# $2 - user
# $3 - pass
_ftc_audit_remote_ftp() {
  local _l_dir="${1:-.}"
  local _l_user="${2:-${FTC_USER}}"
  local _l_pass="${3:-${FTC_PASS}}"
  local _l_host="${FTC_HOST}"
  local _l_port
  _l_port="$(_ftc_effective_port)"
  _ftc_lftp_ssl_init
  local _l_mode_flag
  _l_mode_flag="$(_ftc_lftp_mode_flag)"

  pu_log_i "FTC| Remote audit (${FTC_PROTOCOL}) as ${_l_user} on ${_l_host}:${_l_port} dir=${_l_dir}"
  lftp --norc -c \
    "${_FTC_LFTP_SSL_SETTINGS} ${_l_mode_flag} \
     open ${_FTC_LFTP_URL_SCHEME}://${_l_host}:${_l_port}; \
     user ${_l_user} ${_l_pass}; \
     pwd; \
     ls ${_l_dir}; \
     bye" 2>&1 | while IFS= read -r _line; do pu_log_i "FTC|  remote> ${_line}"; done
}

# Audit remote state via SFTP
# $1 - remote directory to list (optional, default: .)
# $2 - user
# $3 - pass
_ftc_audit_remote_sftp() {
  local _l_dir="${1:-.}"
  local _l_user="${2:-${FTC_USER}}"
  local _l_pass="${3:-${FTC_PASS}}"
  local _l_host="${FTC_HOST}"
  local _l_port
  _l_port="$(_ftc_effective_port)"
  local _l_identity
  _l_identity="$(_ftc_ssh_identity_file)"

  pu_log_i "FTC| Remote audit (sftp/${FTC_KEY_TYPE}) as ${_l_user} on ${_l_host}:${_l_port} dir=${_l_dir}"

  if [ -f "${_l_identity}" ]; then
    sftp \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -i "${_l_identity}" \
      -P "${_l_port}" \
      "${_l_user}@${_l_host}" << EOF 2>&1 | while IFS= read -r _line; do pu_log_i "FTC|  remote> ${_line}"; done
pwd
ls ${_l_dir}
bye
EOF
  else
    SSHPASS="${_l_pass}" sshpass -e sftp \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -P "${_l_port}" \
      "${_l_user}@${_l_host}" << EOF 2>&1 | while IFS= read -r _line; do pu_log_i "FTC|  remote> ${_line}"; done
pwd
ls ${_l_dir}
bye
EOF
  fi
}

# Dispatch remote audit to the right protocol implementation
# $1 - remote directory to list (optional)
# $2 - user (optional)
# $3 - pass (optional)
ftc_audit_remote_state() {
  case "${FTC_PROTOCOL}" in
    ftp | ftps | ftps-implicit) _ftc_audit_remote_ftp "${1}" "${2}" "${3}" ;;
    sftp) _ftc_audit_remote_sftp "${1}" "${2}" "${3}" ;;
    *)
      pu_log_e "FTC| Unknown protocol: ${FTC_PROTOCOL}"
      return 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════
# Login check (returns 0 on success, 1 on failure)
# ═══════════════════════════════════════════════════════════════════════════

# Verify login via FTP/FTPS/FTPS-implicit
# $1 - user, $2 - pass
_ftc_login_ftp() {
  local _l_user="${1:-${FTC_USER}}"
  local _l_pass="${2:-${FTC_PASS}}"
  local _l_host="${FTC_HOST}"
  local _l_port
  _l_port="$(_ftc_effective_port)"
  _ftc_lftp_ssl_init

  pu_log_i "FTC| Login check (${FTC_PROTOCOL}) as ${_l_user} on ${_l_host}:${_l_port}"
  if lftp --norc -c \
    "${_FTC_LFTP_SSL_SETTINGS} \
     open ${_FTC_LFTP_URL_SCHEME}://${_l_host}:${_l_port}; \
     user ${_l_user} ${_l_pass}; \
     pwd; \
     bye" > /dev/null 2>&1; then
    pu_log_i "FTC| Login succeeded for ${_l_user}"
    return 0
  else
    pu_log_e "FTC| Login FAILED for ${_l_user}"
    return 1
  fi
}

# Verify login via SFTP
# $1 - user, $2 - pass
_ftc_login_sftp() {
  local _l_user="${1:-${FTC_USER}}"
  local _l_pass="${2:-${FTC_PASS}}"
  local _l_host="${FTC_HOST}"
  local _l_port
  _l_port="$(_ftc_effective_port)"
  local _l_identity
  _l_identity="$(_ftc_ssh_identity_file)"

  pu_log_i "FTC| Login check (sftp/${FTC_KEY_TYPE}) as ${_l_user} on ${_l_host}:${_l_port}"

  # Use a temp batch file so sftp stdin is free for the SSH handshake.
  # Piping commands via stdin conflicts with sftp's interactive auth prompts.
  local _l_batch
  _l_batch="$(mktemp /tmp/sftp-batch.XXXXXX)"
  printf 'pwd\nbye\n' > "${_l_batch}"

  if [ -f "${_l_identity}" ]; then
    pu_log_d "FTC| DEBUG: Using identity file: ${_l_identity}"
    pu_log_d "FTC| DEBUG: Identity file permissions: $(ls -l "${_l_identity}" 2>&1)"
    pu_log_d "FTC| DEBUG: Identity file first line: $(head -n1 "${_l_identity}" 2>&1)"

    local _l_debug_output
    _l_debug_output="$(mktemp /tmp/sftp-debug.XXXXXX)"

    if sftp -vvv \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -o BatchMode=yes \
      -i "${_l_identity}" \
      -P "${_l_port}" \
      -b "${_l_batch}" \
      "${_l_user}@${_l_host}" > "${_l_debug_output}" 2>&1; then
      rm -f "${_l_batch}"
      pu_log_i "FTC| Login succeeded for ${_l_user} (key: ${FTC_KEY_TYPE})"
      pu_log_d "FTC| DEBUG: SFTP output (last 20 lines):"
      tail -n 20 "${_l_debug_output}" | while IFS= read -r line; do pu_log_d "  ${line}"; done
      rm -f "${_l_debug_output}"
      return 0
    else
      rm -f "${_l_batch}"
      pu_log_e "FTC| Login FAILED for ${_l_user} (key: ${FTC_KEY_TYPE})"
      pu_log_e "FTC| DEBUG: Full SFTP error output:"
      cat "${_l_debug_output}" | while IFS= read -r line; do pu_log_e "  ${line}"; done
      rm -f "${_l_debug_output}"
      return 1
    fi
  else
    pu_log_w "FTC| Identity file not found: ${_l_identity}; using password auth"
    pu_log_d "FTC| DEBUG: Password length: ${#_l_pass} chars"

    local _l_debug_output
    _l_debug_output="$(mktemp /tmp/sftp-debug.XXXXXX)"

    if SSHPASS="${_l_pass}" sshpass -e sftp -vvv \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -P "${_l_port}" \
      -b "${_l_batch}" \
      "${_l_user}@${_l_host}" > "${_l_debug_output}" 2>&1; then
      rm -f "${_l_batch}"
      pu_log_i "FTC| Login succeeded for ${_l_user} (password auth)"
      pu_log_d "FTC| DEBUG: SFTP output (last 20 lines):"
      tail -n 20 "${_l_debug_output}" | while IFS= read -r line; do pu_log_d "  ${line}"; done
      rm -f "${_l_debug_output}"
      return 0
    else
      rm -f "${_l_batch}"
      pu_log_e "FTC| Login FAILED for ${_l_user} (password auth)"
      pu_log_e "FTC| DEBUG: Full SFTP error output:"
      cat "${_l_debug_output}" | while IFS= read -r line; do pu_log_e "  ${line}"; done
      rm -f "${_l_debug_output}"
      return 1
    fi
  fi
}

# Dispatch login check to the right protocol implementation
# $1 - user (optional), $2 - pass (optional)
ftc_login() {
  case "${FTC_PROTOCOL}" in
    ftp | ftps | ftps-implicit) _ftc_login_ftp "${1}" "${2}" ;;
    sftp) _ftc_login_sftp "${1}" "${2}" ;;
    *)
      pu_log_e "FTC| Unknown protocol: ${FTC_PROTOCOL}"
      return 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════
# PUT (upload) operations
# ═══════════════════════════════════════════════════════════════════════════

# Upload a local file to a remote directory via FTP/FTPS/FTPS-implicit
# $1 - local file path
# $2 - remote directory (optional, default: FTC_REMOTE_UPLOAD_DIR)
# $3 - user (optional), $4 - pass (optional)
_ftc_put_ftp() {
  local _l_local_file="${1}"
  local _l_remote_dir="${2:-${FTC_REMOTE_UPLOAD_DIR}}"
  local _l_user="${3:-${FTC_USER}}"
  local _l_pass="${4:-${FTC_PASS}}"
  local _l_host="${FTC_HOST}"
  local _l_port
  _l_port="$(_ftc_effective_port)"
  _ftc_lftp_ssl_init
  local _l_mode_flag
  _l_mode_flag="$(_ftc_lftp_mode_flag)"

  pu_log_i "FTC| PUT (${FTC_PROTOCOL}) ${_l_local_file} -> ${_l_remote_dir}/ on ${_l_host}:${_l_port}"
  if lftp --norc -c \
    "${_FTC_LFTP_SSL_SETTINGS} ${_l_mode_flag} \
     open ${_FTC_LFTP_URL_SCHEME}://${_l_host}:${_l_port}; \
     user ${_l_user} ${_l_pass}; \
     cd ${_l_remote_dir}; \
     put ${_l_local_file}; \
     bye" > /dev/null 2>&1; then
    pu_log_i "FTC| PUT succeeded: $(basename "${_l_local_file}")"
    return 0
  else
    pu_log_e "FTC| PUT FAILED: ${_l_local_file}"
    return 1
  fi
}

# Upload a local file to a remote directory via SFTP
# $1 - local file path
# $2 - remote directory (optional, default: FTC_REMOTE_UPLOAD_DIR)
# $3 - user (optional), $4 - pass (optional)
_ftc_put_sftp() {
  local _l_local_file="${1}"
  local _l_remote_dir="${2:-${FTC_REMOTE_UPLOAD_DIR}}"
  local _l_user="${3:-${FTC_USER}}"
  local _l_pass="${4:-${FTC_PASS}}"
  local _l_host="${FTC_HOST}"
  local _l_port
  _l_port="$(_ftc_effective_port)"
  local _l_identity
  _l_identity="$(_ftc_ssh_identity_file)"

  pu_log_i "FTC| PUT (sftp/${FTC_KEY_TYPE}) ${_l_local_file} -> ${_l_remote_dir}/ on ${_l_host}:${_l_port}"

  if [ -f "${_l_identity}" ]; then
    sftp \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -i "${_l_identity}" \
      -P "${_l_port}" \
      "${_l_user}@${_l_host}" << EOF > /dev/null 2>&1
cd ${_l_remote_dir}
put ${_l_local_file}
bye
EOF
  else
    SSHPASS="${_l_pass}" sshpass -e sftp \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -P "${_l_port}" \
      "${_l_user}@${_l_host}" << EOF > /dev/null 2>&1
cd ${_l_remote_dir}
put ${_l_local_file}
bye
EOF
  fi

  local _l_rc=$?
  if [ ${_l_rc} -eq 0 ]; then
    pu_log_i "FTC| PUT succeeded: $(basename "${_l_local_file}")"
    return 0
  else
    pu_log_e "FTC| PUT FAILED: ${_l_local_file} (rc=${_l_rc})"
    return 1
  fi
}

# Dispatch PUT to the right protocol implementation
# $1 - local file path
# $2 - remote directory (optional)
# $3 - user (optional), $4 - pass (optional)
ftc_put() {
  case "${FTC_PROTOCOL}" in
    ftp | ftps | ftps-implicit) _ftc_put_ftp "${1}" "${2}" "${3}" "${4}" ;;
    sftp) _ftc_put_sftp "${1}" "${2}" "${3}" "${4}" ;;
    *)
      pu_log_e "FTC| Unknown protocol: ${FTC_PROTOCOL}"
      return 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════
# GET (download) operations
# ═══════════════════════════════════════════════════════════════════════════

# Download a remote file to a local path via FTP/FTPS/FTPS-implicit
# $1 - remote file path (relative to login root)
# $2 - local destination file path
# $3 - user (optional), $4 - pass (optional)
_ftc_get_ftp() {
  local _l_remote_file="${1}"
  local _l_local_dest="${2}"
  local _l_user="${3:-${FTC_USER}}"
  local _l_pass="${4:-${FTC_PASS}}"
  local _l_host="${FTC_HOST}"
  local _l_port
  _l_port="$(_ftc_effective_port)"
  _ftc_lftp_ssl_init
  local _l_mode_flag
  _l_mode_flag="$(_ftc_lftp_mode_flag)"
  local _l_local_dir
  _l_local_dir="$(dirname "${_l_local_dest}")"
  local _l_local_name
  _l_local_name="$(basename "${_l_local_dest}")"

  mkdir -p "${_l_local_dir}"
  pu_log_i "FTC| GET (${FTC_PROTOCOL}) ${_l_remote_file} -> ${_l_local_dest} on ${_l_host}:${_l_port}"
  if lftp --norc -c \
    "${_FTC_LFTP_SSL_SETTINGS} ${_l_mode_flag} set xfer:clobber yes; \
     open ${_FTC_LFTP_URL_SCHEME}://${_l_host}:${_l_port}; \
     user ${_l_user} ${_l_pass}; \
     lcd ${_l_local_dir}; \
     get ${_l_remote_file} -o ${_l_local_name}; \
     bye" > /dev/null 2>&1; then
    pu_log_i "FTC| GET succeeded: ${_l_local_dest}"
    return 0
  else
    pu_log_e "FTC| GET FAILED: ${_l_remote_file}"
    return 1
  fi
}

# Download a remote file to a local path via SFTP
# $1 - remote file path (relative to login root)
# $2 - local destination file path
# $3 - user (optional), $4 - pass (optional)
_ftc_get_sftp() {
  local _l_remote_file="${1}"
  local _l_local_dest="${2}"
  local _l_user="${3:-${FTC_USER}}"
  local _l_pass="${4:-${FTC_PASS}}"
  local _l_host="${FTC_HOST}"
  local _l_port
  _l_port="$(_ftc_effective_port)"
  local _l_identity
  _l_identity="$(_ftc_ssh_identity_file)"
  local _l_local_dir
  _l_local_dir="$(dirname "${_l_local_dest}")"
  local _l_local_name
  _l_local_name="$(basename "${_l_local_dest}")"

  mkdir -p "${_l_local_dir}"
  pu_log_i "FTC| GET (sftp/${FTC_KEY_TYPE}) ${_l_remote_file} -> ${_l_local_dest} on ${_l_host}:${_l_port}"

  if [ -f "${_l_identity}" ]; then
    sftp \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -i "${_l_identity}" \
      -P "${_l_port}" \
      "${_l_user}@${_l_host}" << EOF > /dev/null 2>&1
lcd ${_l_local_dir}
get ${_l_remote_file} ${_l_local_name}
bye
EOF
  else
    SSHPASS="${_l_pass}" sshpass -e sftp \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -P "${_l_port}" \
      "${_l_user}@${_l_host}" << EOF > /dev/null 2>&1
lcd ${_l_local_dir}
get ${_l_remote_file} ${_l_local_name}
bye
EOF
  fi

  local _l_rc=$?
  if [ ${_l_rc} -eq 0 ]; then
    pu_log_i "FTC| GET succeeded: ${_l_local_dest}"
    return 0
  else
    pu_log_e "FTC| GET FAILED: ${_l_remote_file} (rc=${_l_rc})"
    return 1
  fi
}

# Dispatch GET to the right protocol implementation
# $1 - remote file path
# $2 - local destination file path
# $3 - user (optional), $4 - pass (optional)
ftc_get() {
  case "${FTC_PROTOCOL}" in
    ftp | ftps | ftps-implicit) _ftc_get_ftp "${1}" "${2}" "${3}" "${4}" ;;
    sftp) _ftc_get_sftp "${1}" "${2}" "${3}" "${4}" ;;
    *)
      pu_log_e "FTC| Unknown protocol: ${FTC_PROTOCOL}"
      return 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════
# Checksum assertion
# ═══════════════════════════════════════════════════════════════════════════

# Assert that a file matches an expected sha256 checksum
# $1 - expected checksum (hex string)
# $2 - file to verify
# Returns 0 if match, 1 otherwise
ftc_assert_checksum() {
  local _l_expected="${1}"
  local _l_file="${2}"

  local _l_actual
  _l_actual="$(ftc_sha256 "${_l_file}")"

  pu_log_i "FTC| Checksum expected : ${_l_expected}"
  pu_log_i "FTC| Checksum actual   : ${_l_actual}"

  if [ "${_l_expected}" = "${_l_actual}" ]; then
    pu_log_i "FTC| Checksum MATCH ✓"
    return 0
  else
    pu_log_e "FTC| Checksum MISMATCH ✗"
    return 1
  fi
}

# Made with Bob
