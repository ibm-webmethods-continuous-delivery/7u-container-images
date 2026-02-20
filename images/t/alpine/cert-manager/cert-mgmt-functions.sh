#!/bin/sh

# shellcheck disable=SC3043

# Function 01 - assures that the passphrase for a subject is available
_cert_mgr_assure_passphrase_for_subject() {
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)

  # Logic:
  # 1. if CRTMGR_PK_PASS exists use that one and warn it is readable.
  #    use this option for testing only
  # 2. Otherwise, check if /dev/shm/cert_mgr/${1}/${2}/passphrase.txt exists
  #    if yes, use that one
  # 3. Otherwise, ask the user for the passphrase using the PU secret reading function pu_read_secret_from_user
  # 4. Store the read passphrase in /dev/shm/cert_mgr${1}/${2}/passphrase.txt
  #    for subsequent use

  local _l_errors=0

  # Input validation
    if [ -z "${1}" ]; then
      pu_log_e "CRTMGR|01| Must pass a subjects base directory in the first parameter"
      _l_errors=$((_l_errors+1))
    fi
    if [ -z "${2}" ]; then
      pu_log_e "CRTMGR|02| Must pass a subject directory in the second parameter"
      _l_errors=$((_l_errors+1))
    fi

    if [ ${_l_errors} -gt 0 ]; then
      return 101 # Validation errors present
    fi

  # Check env var
    if [ ! -z "${CRTMGR_PK_PASS+x}" ]; then
      pu_log_w "CRTMGR|01| CRTMGR_PK_PASS already set for ${1}/${2}, remember to use this approach for testing only!"
      return 0
    fi

  local _l_shm_file="/dev/shm/cert_mgr${1}/${2}/passphrase.txt"
  # Check shm file
    if [ -f "${_l_shm_file}" ]; then
      CRTMGR_PK_PASS=$(cat "${_l_shm_file}")
      return 0
    fi

  # Ask user
    pu_read_secret_from_user "Passphrase for subject ${1}/${2}"
    # shellcheck disable=SC2154
    CRTMGR_PK_PASS="${secret}"
    unset secret
    echo "${CRTMGR_PK_PASS}" > "${_l_shm_file}"
    chmod 400 "${_l_shm_file}"
    return 0
}

# Function 02 - assures encrypted private keys for a subject
_cert_mgr_assure_keys_for_subject(){
    # Generates a private encrypted keypair
    # Params
    # $1 subjects folder name (full path, no trailing slashes)
    # $2 subject folder name (no path, no slashes)
    # $3 encryption passphrase
    # $4 OPTIONAL - RSA key bits size, default 2048

  local _l_errors=0

  # Validation
    if [ -z "${1}" ]; then
      pu_log_e "CRTMGR|02| Must pass a subjects base directory in the first parameter"
      _l_errors=$((_l_errors+1))
    fi

    if [ -z "${2}" ]; then
      pu_log_e "CRTMGR|02| Must pass a subject directory in the second parameter"
      _l_errors=$((_l_errors+1))
    fi
    if [ -z "${3}" ]; then
      pu_log_e "CRTMGR|02| Must pass a passphrase in the third parameter"
      _l_errors=$((_l_errors+1))
    fi

    if [ ${_l_errors} -gt 0 ]; then
      return 101 # Validation errors present
    fi

  _l_errors=0
  # Generate classical RSA private keypair
    local _l_rsa_keypair_file="${1}/${2}/out/private.encrypted.rsa.keypair.pem"

    if [ -f "${_l_rsa_keypair_file}" ]; then
      pu_log_i "CRTMGR|02| Subject folder ${1}/${2}/out already has a RSA key pair. Skipping generation."
    else
      local _l_rsa_bits="${4:-2048}"
      pu_log_i "CRTMGR|02|  Generating private RSA key pair for subject ${2}"
      if ! openssl genrsa \
                  -aes256 \
                  -passout pass:"${3}" \
                  -out "${_l_rsa_keypair_file}" \
                  "${_l_rsa_bits}" ; then
      pu_log_e "CRTMGR|02| RSA key pair generation for subject ${2} failed with result code $?"
        _l_errors=$((_l_errors+1))
      fi
    fi

  # Generate post quantum EdDSA ed25519 key pair
    local _l_ed_keypair_file="${1}/${2}/out/private.encrypted.ed25519.keypair.pem"

    if [ -f "${_l_ed_keypair_file}" ]; then
      pu_log_i "CRTMGR|02| Subject folder ${1}/${2}/out already has an ED25519 key pair. Skipping generation."
    else
      pu_log_i "CRTMGR|02|  Generating private ED25519 key pair for subject ${2}"
      if ! openssl genpkey \
                  -algorithm ed25519 \
                  -pass pass:"${3}" \
                  -out "${_l_ed_keypair_file}" \
                  -outform PEM ; then
      pu_log_e "CRTMGR|02| ED25519 key pair generation for subject ${2} failed with result code $?"
        _l_errors=$((_l_errors+1))
      fi
    fi

  return "${_l_errors}"
}

# Function 03 - Assure Root CA certificate
_cert_mgr_assure_root_ca_cert(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)
  # $3 passphrase for the private key

  pu_log_i "CRTMGR|03| Assuring Root CA certificate for ${1}/${2}..."
  # Init local variables
    local _l_cert_validity_days="${CERTMGR_CERTIFICATE_VALIDITY_DAYS:-365}"
    local _l_ed_keypair_file="${1}/${2}/out/private.encrypted.ed25519.keypair.pem"
    local _l_error_count=0
    local _l_rsa_cert_file="${1}/${2}/out/public.rsa.pem.cer"
    local _l_ed_cert_file="${1}/${2}/out/public.ed25519.pem.cer"
    local _l_rsa_keypair_file="${1}/${2}/out/private.encrypted.rsa.keypair.pem"
    local _l_subject="${CRTMGR_SUBJ_PARAM:-/CN=localhost}"

  ## Prerequisites
    if [ ! -f "${_l_rsa_keypair_file}" ] || [ ! -f "${_l_ed_keypair_file}" ] ; then
      if ! _cert_mgr_assure_keys_for_subject "${1}" "${2}" "${3}" ; then
        pu_log_e "CRTMGR|03| Cannot assure private keys for ${1}/${2}!"
        return 101
      fi
    fi

  ## RSA based
    if [ -f "${_l_rsa_cert_file}" ]; then
      pu_log_i "CRTMGR|03| File ${_l_rsa_cert_file} already exists, skipping..."
    else
      if ! openssl req \
                  -new \
                  -key "${_l_rsa_keypair_file}" \
                  -passin pass:"${3}" \
                  -x509 \
                  -days "${_l_cert_validity_days}" \
                  -subj "${_l_subject}" \
                  -out "${_l_rsa_cert_file}" ; then
        pu_log_e "CRTMGR|03| Failed to create RSA based certificate for ${1}/${2}!"
        _l_error_count=$((_l_error_count + 1))
      fi
    fi

  ## ED25519 based
    if [ -f "${_l_ed_cert_file}" ]; then
      pu_log_i "CRTMGR|03| File ${_l_ed_cert_file} already exists, skipping..."
    else
      if ! openssl req \
                  -new \
                  -key "${_l_ed_keypair_file}" \
                  -passin pass:"${3}" \
                  -x509 \
                  -days "${_l_cert_validity_days}" \
                  -subj "${_l_subject}" \
                  -out "${_l_ed_cert_file}" ; then
        pu_log_e "CRTMGR|03| Failed to create ED25519 based certificate for ${1}/${2}!"
        _l_error_count=$((_l_error_count + 1))
      fi
    fi

  return "${_l_error_count}"
}

# Function 04 - Assure CSR for a subject
_cert_mgr_assure_csr_for_subject(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)
  # $3 passphrase for the private key
  pu_log_i "CRTMGR|04| Assuring CSRs - Certificate Signing Requests for ${1}/${2}..."
  # Init local variables
    local _l_cert_validity_days="${CERTMGR_CERTIFICATE_VALIDITY_DAYS:-365}"
    local _l_ed_keypair_file="${1}/${2}/out/private.encrypted.ed25519.keypair.pem"
    local _l_error_count=0
    local _l_rsa_keypair_file="${1}/${2}/out/private.encrypted.rsa.keypair.pem"
    local _l_csr_config_file="${1}/${2}/csr.config"
    local _l_csr_rsa_out_file="${1}/${2}/out/public.rsa.pem.csr"
    local _l_csr_ed_out_file="${1}/${2}/out/public.ed25519.pem.csr"

  ## Prerequisites
    if [ ! -f "${_l_csr_config_file}" ] ; then
      pu_log_e "CRTMGR|04| Cannot find mandatory CSR config file ${_l_csr_config_file}!"
      return 102
    fi
    if [ ! -f "${_l_rsa_keypair_file}" ] || [ ! -f "${_l_ed_keypair_file}" ] ; then
      if ! _cert_mgr_assure_keys_for_subject "${1}" "${2}" "${3}" ; then
        pu_log_e "CRTMGR|04| Cannot assure private keys for ${1}/${2}!"
        return 101
      fi
    fi

  ## RSA based CSR
    if ! openssl req \
                -new \
                -sha256 \
                -key "${_l_rsa_keypair_file}" \
                -passin pass:"${3}" \
                -out "${_l_csr_rsa_out_file}" \
                -config "${_l_csr_config_file}" ; then
        pu_log_e "CRTMGR|04| Error creating RSA based CSR, code $?"
        _l_error_count=$((_l_error_count+1))
    fi

  ## ED25519 based CSR
    if ! openssl req \
                -new \
                -sha256 \
                -key "${_l_ed_keypair_file}" \
                -passin pass:"${3}" \
                -out "${_l_csr_ed_out_file}" \
                -config "${_l_csr_config_file}" ; then
        pu_log_e "CRTMGR|04| Error creating ED25519 based CSR, code $?"
        _l_error_count=$((_l_error_count+1))
    fi

  return "${_l_error_count}"
}

#### Public functions
# Function 21 - Assures all artifacts for a subject are in place
cert_mgr_manage_subject(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)

  if [ ! -d "${1}/${2}" ]; then
    pu_log_e "CRTMGR|22| Subject folder ${1}/${2} does not exist"
    return 101
  fi
  mkdir -p "${1}/${2}/out"

  if [ -f "${1}/${2}/set-env.sh" ]; then
    pu_log_d "CRTMGR|22| Sourcing existing ${1}/${2}/set-env.sh"
    # shellcheck disable=SC1090
    . "${1}/${2}/set-env.sh"
  else
    pu_log_i "CRTMGR|22| No ${1}/${2}/set-env.sh file to source"
  fi


  _cert_mgr_assure_passphrase_for_subject "${1}" "${2}"

  _cert_mgr_assure_keys_for_subject "${1}" "${2}" "${CRTMGR_PK_PASS}"

  if [ "${CRTMGR_SUBJECT_TYPE}" = "RootCA" ]; then
    # in case of Root CA only the self signed certificate is needed, without CSRs and the other bundled constructs
    _cert_mgr_assure_root_ca_cert "${1}" "${2}" "${CRTMGR_PK_PASS}"
  else
    _cert_mgr_assure_csr_for_subject "${1}" "${2}" "${CRTMGR_PK_PASS}"
    pu_log_i " To continue ..."
  fi

  # Important: ensure these variables do not re-enter for another subject
  unset CRTMGR_PK_PASS CRTMGR_SUBJECT_TYPE
}

# Function 22 - manages all subjects in a folder
cert_mgr_manage_all_subjects(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  pu_log_i "CRTMGR|22| Managing all subjects in folder ${1} ..."
  if [ ! -d "${1}" ]; then
    pu_log_e "CRTMGR|22| Subjects folder ${1} does not exist!"
    return 1
  fi

  local l_crt_pwd
  l_crt_pwd=$(pwd)
  cd "${1}" || return 2
  local _l_subject_folder
  for _l_subject_folder in *; do
    [ -e "${_l_subject_folder}" ] || break # In case there is no subfolder or file, exit the loop
    [ -d "${_l_subject_folder}" ] && cert_mgr_manage_subject "${1}" "${_l_subject_folder}"
  done

  cd "${l_crt_pwd}" || return 3
}
