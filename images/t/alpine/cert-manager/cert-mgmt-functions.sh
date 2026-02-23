#!/bin/sh

# shellcheck disable=SC3043

__cert_mgr_default_truststore_password='cHang3me'

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

  mkdir -p "/dev/shm/cert_mgr${1}/${2}"
  local _l_shm_file="/dev/shm/cert_mgr${1}/${2}/passphrase.txt"

  # Check env var
    if [ ! -z "${CRTMGR_PK_PASS+x}" ]; then
      pu_log_w "CRTMGR|01| CRTMGR_PK_PASS already set for ${1}/${2}, remember to use this approach for testing only!"
      pu_log_d "CRTMGR|01| Writing CRTMGR_PK_PASS to file ${_l_shm_file}"
      echo "${CRTMGR_PK_PASS}" > "${_l_shm_file}"
      return 0
    fi

  # Check shm file
    if [ -f "${_l_shm_file}" ]; then
      pu_log_d "CRTMGR|01| Reading CRTMGR_PK_PASS from file ${_l_shm_file}"
      CRTMGR_PK_PASS=$(cat "${_l_shm_file}")
      return 0
    fi

  # Ask user
    pu_read_secret_from_user "Passphrase for subject ${1}/${2}"
    # shellcheck disable=SC5154
    CRTMGR_PK_PASS="${secret}"
    unset secret
    pu_log_d "CRTMGR|01| Writing CRTMGR_PK_PASS to file ${_l_shm_file}"
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
    local _l_out_rsa_keypair_file="${1}/${2}/out/rsa/private.encrypted.keypair.pem"

    if [ -f "${_l_out_rsa_keypair_file}" ]; then
      pu_log_i "CRTMGR|02| Subject folder ${1}/${2}/out already has a RSA key pair. Skipping generation."
    else
      local _l_out_rsa_bits="${4:-2048}"
      pu_log_i "CRTMGR|02|  Generating private RSA key pair for subject ${2}"

      openssl genrsa \
              -aes256 \
              -passout pass:"${3}" \
              -out "${_l_out_rsa_keypair_file}" \
              "${_l_out_rsa_bits}"
      local _l_res_rsa=$?

      if [ ${_l_res_rsa} -ne 0 ]; then
        pu_log_e "CRTMGR|02| RSA key pair generation for subject ${1}/${2} failed with result code ${_l_res_rsa}"
        _l_errors=$((_l_errors+1))
      fi
    fi

  # Generate post quantum EdDSA ed25519 key pair
    local _l_out_ed_keypair_file="${1}/${2}/out/ed25519/private.encrypted.keypair.pem"

    if [ -f "${_l_out_ed_keypair_file}" ]; then
      pu_log_i "CRTMGR|02| Subject folder ${1}/${2}/out already has an ED25519 key pair. Skipping generation."
    else
      pu_log_i "CRTMGR|02|  Generating private ED25519 key pair for subject ${2}"
      openssl genpkey \
                  -algorithm ed25519 \
                  -pass pass:"${3}" \
                  -out "${_l_out_ed_keypair_file}" \
                  -outform PEM
      local l_res_pk=$?
      if [ ${l_res_pk} -ne 0 ]; then
        pu_log_e "CRTMGR|02| ED25519 key pair generation for subject ${2} failed with result code ${l_res_pk}"
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
    local _l_error_count=0
    local _l_out_ed_cert_file="${1}/${2}/out/ed25519/public.pem.cer"
    local _l_out_ed_keypair_file="${1}/${2}/out/ed25519/private.encrypted.keypair.pem"
    local _l_out_rsa_cert_file="${1}/${2}/out/rsa/public.pem.cer"
    local _l_out_rsa_keypair_file="${1}/${2}/out/rsa/private.encrypted.keypair.pem"
    local _l_subject="${CRTMGR_SUBJ_PARAM:-/CN=localhost}"

  ## Prerequisites
    if [ ! -f "${_l_out_rsa_keypair_file}" ] || [ ! -f "${_l_out_ed_keypair_file}" ] ; then
      if ! _cert_mgr_assure_keys_for_subject "${1}" "${2}" "${3}" ; then
        pu_log_e "CRTMGR|03| Cannot assure private keys for ${1}/${2}!"
        return 101
      fi
    fi

  ## RSA based
    if [ -f "${_l_out_rsa_cert_file}" ]; then
      pu_log_i "CRTMGR|03| File ${_l_out_rsa_cert_file} already exists, skipping..."
      if [ ! -f "${1}/${2}/out/rsa/public.crt.bundle.pem" ]; then
        pu_log_i "CRTMGR|03| File ${1}/${2}/out/rsa/public.crt.bundle.pem does not exist, generating..."
        cat "${_l_out_rsa_cert_file}" > "${1}/${2}/out/rsa/public.crt.bundle.pem"
      fi
    else
      openssl req \
              -new \
              -key "${_l_out_rsa_keypair_file}" \
              -passin pass:"${3}" \
              -x509 \
              -days "${_l_cert_validity_days}" \
              -subj "${_l_subject}" \
              -out "${_l_out_rsa_cert_file}"
      local _l_res_rsa=$?
      if [ ${_l_res_rsa} -ne 0 ]; then
        pu_log_e "CRTMGR|03| Failed to create RSA based certificate for ${1}/${2}, code ${_l_res_rsa}!"
        _l_error_count=$((_l_error_count + 1))
      else
        cat "${_l_out_rsa_cert_file}" > "${1}/${2}/out/rsa/public.crt.bundle.pem"
      fi
    fi

  ## ED25519 based
    if [ -f "${_l_out_ed_cert_file}" ]; then
      pu_log_i "CRTMGR|03| File ${_l_out_ed_cert_file} already exists, skipping..."
      if [ ! -f "${1}/${2}/out/ed25519/public.crt.bundle.pem" ]; then
        pu_log_i "CRTMGR|03| File ${1}/${2}/out/ed25519/public.crt.bundle.pem does not exists, generating..."
        cat "${_l_out_ed_cert_file}" > "${1}/${2}/out/ed25519/public.crt.bundle.pem"
      fi
    else
      openssl req \
              -new \
              -key "${_l_out_ed_keypair_file}" \
              -passin pass:"${3}" \
              -x509 \
              -days "${_l_cert_validity_days}" \
              -subj "${_l_subject}" \
              -out "${_l_out_ed_cert_file}"
      local _l_res_ed=$?
      if [ ${_l_res_ed} -ne 0 ]; then
        pu_log_e "CRTMGR|03| Failed to create ED25519 based certificate for ${1}/${2}, code ${_l_res_ed}!"
        _l_error_count=$((_l_error_count + 1))
      else
        cat "${_l_out_ed_cert_file}" > "${1}/${2}/out/ed25519/public.crt.bundle.pem"
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
    #local _l_cert_validity_days="${CERTMGR_CERTIFICATE_VALIDITY_DAYS:-365}"
    local _l_out_ed_keypair_file="${1}/${2}/out/ed25519/private.encrypted.keypair.pem"
    local _l_error_count=0
    local _l_out_rsa_keypair_file="${1}/${2}/out/rsa/private.encrypted.keypair.pem"
    local _l_csr_config_file="${1}/${2}/csr.config"
    local _l_out_rsa_scr_file="${1}/${2}/out/rsa/public.pem.csr"
    local _l_out_ed_scr_file="${1}/${2}/out/ed25519/public.pem.csr"

  ## Prerequisites
    if [ ! -f "${_l_csr_config_file}" ] ; then
      pu_log_e "CRTMGR|04| Cannot find mandatory CSR config file ${_l_csr_config_file}!"
      return 102
    fi
    if [ ! -f "${_l_out_rsa_keypair_file}" ] || [ ! -f "${_l_out_ed_keypair_file}" ] ; then
      if ! _cert_mgr_assure_keys_for_subject "${1}" "${2}" "${3}" ; then
        pu_log_e "CRTMGR|04| Cannot assure private keys for ${1}/${2}!"
        return 101
      fi
    fi

  ## RSA based CSR
    if ! openssl req \
                -new \
                -sha256 \
                -key "${_l_out_rsa_keypair_file}" \
                -passin pass:"${3}" \
                -out "${_l_out_rsa_scr_file}" \
                -config "${_l_csr_config_file}" ; then
        pu_log_e "CRTMGR|04| Error creating RSA based CSR, code $?"
        _l_error_count=$((_l_error_count+1))
    fi

  ## ED25519 based CSR
    if ! openssl req \
                -new \
                -sha256 \
                -key "${_l_out_ed_keypair_file}" \
                -passin pass:"${3}" \
                -out "${_l_out_ed_scr_file}" \
                -config "${_l_csr_config_file}" ; then
        pu_log_e "CRTMGR|04| Error creating ED25519 based CSR, code $?"
        _l_error_count=$((_l_error_count+1))
    fi

  return "${_l_error_count}"
}

# Function 05 - Assure Certificates for Subject
_cert_mgr_assure_cert_for_subject(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)
  # Notes:
  #   the subject's set-env MUST contain the folder name for the signing CA, which MUST exist in the same subjects folder
  #   The prerequisites MUST be assured before calling this function: subject's csr and CA private key and certificate

  pu_log_i "CRTMGR|05| Assuring certificates for ${1}/${2}"

  ## Local variables
    local _l_ca_signing_dir="${CRTMGR_SIGNING_CA_SUBJECT_DIR}"
    local _l_cert_gen_config_file="${1}/${2}/cert-gen.config"
    local _l_cert_validity_days="${CERTMGR_CERTIFICATE_VALIDITY_DAYS:-365}"
    local _l_csr_ed_input_file="${1}/${2}/out/ed25519/public.pem.csr"
    local _l_csr_rsa_input_file="${1}/${2}/out/rsa/public.pem.csr"
    local _l_error_count=0
    local _l_out_ed_cert_bundle_file="${1}/${2}/out/ed25519/public.crt.bundle.pem"
    local _l_out_ed_cert_file="${1}/${2}/out/ed25519/public.pem.cer"
    local _l_out_rsa_cert_bundle_file="${1}/${2}/out/rsa/public.crt.bundle.pem"
    local _l_out_rsa_cert_file="${1}/${2}/out/rsa/public.pem.cer"
    local _l_set_env_file="${1}/${2}/set-env.sh"
    local _l_shm_file="/dev/shm/cert_mgr${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/passphrase.txt"


  ## Output exists shortcut
    if [ -f "${_l_out_ed_cert_file}" ] \
    && [ -f "${_l_out_ed_cert_bundle_file}" ] \
    && [ -f "${_l_out_rsa_cert_file}" ] \
    && [ -f "${_l_out_rsa_cert_bundle_file}" ] \
    ; then
      pu_log_i "CRTMGR|11| Certificates already exist, skipping..."
      return 0
    fi

  ## Prerequisites
    if [ ! -f "${_l_set_env_file}" ]; then
      pu_log_e "CRTMGR|05| Mandatory file ${_l_set_env_file} not found!"
      _l_error_count=$((_l_error_count+1))
    else
      # shellcheck disable=SC1090
      . "${_l_set_env_file}"
    fi

    if [ ! -f "${_l_csr_ed_input_file}" ]; then
      pu_log_e "CRTMGR|05| Mandatory file ${_l_csr_ed_input_file} not found!"
      _l_error_count=$((_l_error_count+1))
    fi

    if [ ! -f "${_l_csr_rsa_input_file}" ]; then
      pu_log_e "CRTMGR|05| Mandatory file ${_l_csr_rsa_input_file} not found!"
      _l_error_count=$((_l_error_count+1))
    fi

    if [ -z ${CRTMGR_SIGNING_CA_SUBJECT_DIR+x} ]; then
      pu_log_e "CRTMGR|05| Mandatory environment variable CRTMGR_SIGNING_CA_SUBJECT_DIR not set!"
      _l_error_count=$((_l_error_count+1))
    else
      if [ ! -f "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/rsa/private.encrypted.keypair.pem" ]; then
        pu_log_e "Mandatory file ${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/rsa/private.encrypted.keypair.pem does not exist"
        _l_error_count=$((_l_error_count+1))
      fi
      if [ ! -f "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/ed25519/private.encrypted.keypair.pem" ]; then
        pu_log_e "Mandatory file ${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/ed25519/private.encrypted.keypair.pem does not exist"
        _l_error_count=$((_l_error_count+1))
      fi
      if [ ! -f "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/rsa/public.pem.cer" ]; then
        pu_log_e "Mandatory file ${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/rsa/public.pem.cer does not exist"
        _l_error_count=$((_l_error_count+1))
      fi
      if [ ! -f "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/ed25519/public.pem.cer" ]; then
        pu_log_e "Mandatory file ${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/ed25519/public.pem.cer does not exist"
        _l_error_count=$((_l_error_count+1))
      fi

      if [ ! -f "${_l_shm_file}" ]; then
        pu_log_e "Mandatory file ${_l_shm_file} does not exist"
        _l_error_count=$((_l_error_count+1))
      fi
    fi

    if [ ${_l_error_count} -ne 0 ]; then
      return 102
    fi

  ## Get the passphrase for the CA PK


    local _l_ca_passphrase
    _l_ca_passphrase=$(cat "${_l_shm_file}")

  _l_error_count=0 # reset error count after validations
  ## Create RSA based certificate
    if [ ! -f "${_l_out_rsa_cert_file}" ]; then
      pu_log_i "CRTMGR|05| Creating RSA based certificate..."

      openssl x509 \
              -req \
              -days "${_l_cert_validity_days}" \
              -in "${_l_csr_rsa_input_file}" \
              -CA "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/rsa/public.pem.cer" \
              -CAkey "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/rsa/private.encrypted.keypair.pem" \
              -passin pass:"${_l_ca_passphrase}" \
              -CAcreateserial \
              -out "${_l_out_rsa_cert_file}" \
              -extfile "${_l_cert_gen_config_file}" \
              -extensions EXTENSIONS
      local _l_res_rsa=$?
      if [ ${_l_res_rsa} -ne 0 ]; then
        pu_log_e "CRTMGR|06| Error creating RSA based certificate! Code ${_l_res_rsa}"
      fi
    fi

  ## Create RSA Based public certificate bundle
    if [ ! -f "${_l_out_rsa_cert_bundle_file}" ]; then
      pu_log_i "CRTMGR|05| Creating RSA based certificate bundle..."
      if [ ! -f "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/rsa/public.crt.bundle.pem" ];    then
        pu_log_e "CRTMGR|06| Error: Signing CA public certificate bundle not found! Cannot create bundle for ${1}/${2}!"
      else
        cat \
          "${_l_out_rsa_cert_file}" \
          "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/rsa/public.crt.bundle.pem" \
          > "${_l_out_rsa_cert_bundle_file}"
      fi
    fi

  ## Create ED25519 based certificate
    if [ ! -f "${_l_out_ed_cert_file}" ]; then
      pu_log_i "CRTMGR|05| Creating ED25519 based certificate..."
      if ! openssl x509 \
                  -req \
                  -days "${_l_cert_validity_days}" \
                  -in "${_l_csr_ed_input_file}" \
                  -CA "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/ed25519/public.pem.cer" \
                  -CAkey "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/ed25519/private.encrypted.keypair.pem" \
                  -passin pass:"${_l_ca_passphrase}" \
                  -CAcreateserial \
                  -out "${_l_out_ed_cert_file}" \
                  -extfile "${_l_cert_gen_config_file}" \
                  -extensions EXTENSIONS ; then
        pu_log_w "CRTMGR|05| Certificate generation failed with code $?"
      fi
    fi

  ## Create RSA Based public certificate bundle
  if [ ! -f "${_l_out_ed_cert_bundle_file}" ]; then
    pu_log_i "CRTMGR|05| Creating RSA based certificate bundle..."
    if [ ! -f "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/ed25519/public.crt.bundle.pem" ];    then
      pu_log_e "CRTMGR|06| Error: Signing CA public certificate bundle not found! Cannot create bundle for ${1}/${2}!"
    else
      cat \
        "${_l_out_ed_cert_file}" \
        "${1}/${CRTMGR_SIGNING_CA_SUBJECT_DIR}/out/ed25519/public.crt.bundle.pem" \
        > "${_l_out_ed_cert_bundle_file}"
    fi
  fi
}

# Function 06 - Assure Key and Certificate Bundles For Subject{
_cert_mgr_assure_key_cert_bundles_for_subject(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)

  # TODO: Exception management

  pu_log_i "CRTMGR|06| Assuring key and certificate bundles for subject: ${1}/${2}"

  if [ ! -f "${1}/${2}/out/rsa/private.encrypted.keypair.cert.bundle.pem" ] ; then
    pu_log_i "CRTMGR|06| Generating RSA key and certificate bundles for subject: ${1}/${2}"
    cat \
      "${1}/${2}/out/rsa/private.encrypted.keypair.pem" \
      "${1}/${2}/out/rsa/public.pem.cer" \
      > "${1}/${2}/out/rsa/private.encrypted.keypair.cert.bundle.pem"
  fi
  if [ ! -f "${1}/${2}/out/ed25519/private.encrypted.keypair.cert.bundle.pem" ] ; then
    pu_log_i "CRTMGR|06| Generating ED25519 key and certificate bundles for subject: ${1}/${2}"
    cat \
      "${1}/${2}/out/ed25519/private.encrypted.keypair.pem" \
      "${1}/${2}/out/ed25519/public.pem.cer" \
      > "${1}/${2}/out/ed25519/private.encrypted.keypair.cert.bundle.pem"
  fi
}

# Function 07 - Assure PKCS12 Private Key Stores store for subject
_cert_mgr_assure_pkcs12_private_keys_store_for_subject(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)
  # $3 passphrase for the private key
  # $4 Signing CA Subject Name - Single folder no path, no slashes
  pu_log_i "CRTMGR|07| Assuring PKCS12 Private Keys store for subject ${1}/${2}..."
  local _l_res_1=0
  local _l_res_2=0

  if [ ! -f "${1}/${2}/out/rsa/private.key.store.p12" ]; then
    pu_log_i "CRTMGR|07| Generating RSA based PKCS12 Private Keys store for subject ${1}/${2}..."
    openssl pkcs12 \
            -export \
            -in "${1}/${2}/out/rsa/public.pem.cer" \
            -inkey "${1}/${2}/out/rsa/private.encrypted.keypair.pem" \
            -passin pass:"${3}" \
            -out "${1}/${2}/out/rsa/private.key.store.p12"  \
            -passout pass:"${3}" \
            -CAfile "${1}/${4}/out/rsa/public.pem.cer"
    _l_res_1=$?
    if [ ${_l_res_1} -ne 0 ]; then
      pu_log_e "CRTMGR|07| Failed to generate RAS PKCS12 Private Keys store for subject ${1}/${2}, code ${_l_res_1}"
    fi
  fi

  if [ ! -f "${1}/${2}/out/ed25519/private.key.store.p12" ]; then
    pu_log_i "CRTMGR|07| Generating ED25519 based PKCS12 Private Keys store for subject ${1}/${2}..."

    openssl pkcs12 \
            -export \
            -in "${1}/${2}/out/ed25519/public.pem.cer" \
            -inkey "${1}/${2}/out/ed25519/private.encrypted.keypair.pem" \
            -passin pass:"${3}" \
            -out "${1}/${2}/out/ed25519/private.key.store.p12"  \
            -passout pass:"${3}" \
            -CAfile "${1}/${4}/out/ed25519/public.pem.cer"
    _l_res_2=$?
    if [ ${_l_res_2} -ne 0 ]; then
      pu_log_e "CRTMGR|07| Failed to generate ED25519 PKCS12 Private Keys store for subject ${1}/${2}, code ${_l_res_2}"
    fi
  fi

  if [ "${_l_res_2}" -eq 0 ] && [ "${_l_res_1}" -eq 0 ] ; then
    return 0
  fi
  return 1
}

# Function 08 - Assure PKCS12 Private Key Stores with full chain store for subject
_cert_mgr_assure_pkcs12_private_keys_store_with_chain_for_subject(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)
  # $3 passphrase for the private key
  # $4 Signing CA Subject Folder Name - Single folder no path, no slashes
  # $5 OPTIONAL Signing CA Subject Name - as in "Subject" for the CA/DN
  # $6 - Keystore entry name

  pu_log_i "CRTMGR|08| Assuring PKCS12 Private Keys store with full chain for subject ${1}/${2}..."

  local _l_key_story_entry="${6:-$2}"
  local _l_ca_name="${5:-$4}"
  local _l_res_rsa=0
  local _l_res_ed25519=0

  if [ ! -f "${1}/${2}/out/rsa/full.chain.key.store.p12" ]; then
    pu_log_i "CRTMGR|08| Generating PKCS12 RSA Private Keys store with full chain for subject ${1}/${2}..."
    openssl pkcs12 \
            -export \
            -in "${1}/${2}/out/rsa/public.pem.cer" \
            -inkey "${1}/${2}/out/rsa/private.encrypted.keypair.pem" \
            -passin pass:"${3}" \
            -out "${1}/${2}/out/rsa/full.chain.key.store.p12"  \
            -passout pass:"${3}" \
            -name "${_l_key_story_entry}" \
            -CAfile "${1}/${4}/out/rsa/public.crt.bundle.pem" \
            -caname "${_l_ca_name}" \
            -chain
    _l_res_rsa=$?
    if [ ${_l_res_rsa} -ne 0 ]; then
      pu_log_e "CRTMGR|08| Error generating PKCS12 RSA Private Keys store with full chain for subject ${1}/${2}. Code ${_l_res_rsa}"
    fi
  fi

  if [ ! -f "${1}/${2}/out/ed25519/full.chain.key.store.p12" ]; then
    pu_log_i "CRTMGR|08| Generating PKCS12 ED25519 Private Keys store with full chain for subject ${1}/${2}..."
    openssl pkcs12 \
            -export \
            -in "${1}/${2}/out/ed25519/public.pem.cer" \
            -inkey "${1}/${2}/out/ed25519/private.encrypted.keypair.pem" \
            -passin pass:"${3}" \
            -out "${1}/${2}/out/ed25519/full.chain.key.store.p12"  \
            -passout pass:"${3}" \
            -name "${_l_key_story_entry}" \
            -CAfile "${1}/${4}/out/ed25519/public.crt.bundle.pem" \
            -caname "${_l_ca_name}" \
            -chain
    _l_res_ed25519=$?
    if [ ${_l_res_ed25519} -ne 0 ]; then
      pu_log_e "CRTMGR|08| Error generating PKCS12 RSA Private Keys store with full chain for subject ${1}/${2}. Code ${_l_res_ed25519}"
    fi
  fi

  if [ "${_l_res_ed25519}" -eq 0 ] && [ "${_l_res_rsa}" -eq 0 ]; then
    return 0
  fi

  return 1
}

# Function 09 - Assure PKCS12 Trust Stores with Public Certificates for a subject
_cert_mgr_assure_pkcs12_trust_store_for_subject(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)
  # $3 key entryname

  local _l_key_entry_name="${3:-$2}"
  local _l_error_count=0

  # RSA
    if [ ! -f "${1}/${2}/out/rsa/public.trust.store.p12" ] ; then
      pu_log_i "CRTMGR|09| Generating single entry PKCS12 trust store for subject ${1}/${2}, RSA based key entry name: ${_l_key_entry_name}"
      openssl pkcs12 -export -nokeys \
              -in "${1}/${2}/out/rsa/public.pem.cer" \
              -out "${1}/${2}/out/rsa/public.trust.store.p12" \
              -passout pass:"${__cert_mgr_default_truststore_password}" \
              -name "${3}"
      local _l_result_rsa=$?
      if [ ${_l_result_rsa} -ne 0 ]; then
        pu_log_e "CRTMGR|09| Error creating RSA keys PKCS12 trust store for subject ${1}/${2}, code ${_l_result_rsa}"
        _l_error_count=$((_l_error_count+1))
      fi
    fi

  # ED25519
    if [ ! -f "${1}/${2}/out/ed25519/public.trust.store.p12" ] ; then
      pu_log_i "CRTMGR|09| Generating single entry PKCS12 trust store for subject ${1}/${2}, ED25519 based key entry name: ${_l_key_entry_name}"
      openssl pkcs12 -export -nokeys \
              -in "${1}/${2}/out/ed25519/public.pem.cer" \
              -out "${1}/${2}/out/ed25519/public.trust.store.p12" \
              -passout pass:"${__cert_mgr_default_truststore_password}" \
              -name "${_l_key_entry_name}"
      local _l_result_ed25519=$?
      if [ ${_l_result_ed25519} -ne 0 ]; then
        pu_log_e "CRTMGR|09| Error creating RSA keys PKCS12 trust store for subject ${1}/${2}, code ${_l_result_ed25519}"
        _l_error_count=$((_l_error_count+1))
      fi
    fi

  return ${_l_error_count}
}

# Functions 31-40 Java releted

# Function 31 - Simple JKS truststore with only the subject's certificate
_cert_mgr_assure_simple_jks_truststore_for_subject(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)
  # $3 subject key store entry name

  pu_log_i "CRTMGR|31| Assuring simple JKS truststore for subject ${1}/${2}..."

  local _l_error_count=0

  # RSA
    if [ ! -f "${1}/${2}/out/rsa/simple.trust.store.jks" ]; then
      pu_log_i "CRTMGR|31| Creating file ${1}/${2}/out/rsa/simple.trust.store.jks ..."
      keytool -import \
        -keystore "${1}/${2}/out/rsa/simple.trust.store.jks" \
        -file "${1}/${2}/out/rsa/public.pem.cer" \
        -alias "${3}" \
        -storepass "${__cert_mgr_default_truststore_password}" \
        -noprompt

      local result=$?
      if [ "$result" -ne 0 ]; then
        pu_log_e "CRTMGR|31| Simple public JKS store generation for subject ${1} failed with result code $result"
        _l_error_count=$((_l_error_count+1))
      fi
    fi

  # ED25519
    if [ ! -f "${1}/${2}/out/ed25519/simple.trust.store.jks" ]; then
      pu_log_i "CRTMGR|31| Creating file ${1}/${2}/out/ed25519/simple.trust.store.jks ..."
      keytool -import \
        -keystore "${1}/${2}/out/ed25519/simple.trust.store.jks" \
        -file "${1}/${2}/out/ed25519/public.pem.cer" \
        -alias "${3}" \
        -storepass "${__cert_mgr_default_truststore_password}" \
        -noprompt

      local result=$?
      if [ "$result" -ne 0 ]; then
        pu_log_e "CRTMGR|31| Simple public JKS store generation for subject ${1} failed with result code $result"
        _l_error_count=$((_l_error_count+1))
      fi
    fi

}

# Function 32 - JKS Full chain Keystore for subject
_cert_mgr_assure_full_chain_jks_keystore_for_subject(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)
  # $3 passphrase for the subject (unique on all subject's protected files)
  # $4 KeyStore entry alias

  local _l_error_count=0

  # RSA
    if [ ! -f "${1}/${2}/out/rsa/full.chain.key.store.jks" ]; then
      keytool -importkeystore \
        -destkeystore "${1}/${2}/out/rsa/full.chain.key.store.jks" \
        -srckeystore "${1}/${2}/out/rsa/full.chain.key.store.p12" \
        -srcalias "${4}" \
        -srcstoretype PKCS12 \
        -destalias "${4}" \
        -srcstorepass "${3}" \
        -deststorepass "${3}"
      local _l_res_rsa=$?
      if [ ${_l_res_rsa} -ne 0 ]; then
        pu_log_e "CRTMGR|32| Failed to import RSA key store for subject ${2}"
        _l_error_count=$((_l_error_count+1))
      fi
    fi
  # ED25519
    if [ ! -f "${1}/${2}/out/ed25519/full.chain.key.store.jks" ]; then
      keytool -importkeystore \
        -destkeystore "${1}/${2}/out/ed25519/full.chain.key.store.jks" \
        -srckeystore "${1}/${2}/out/ed25519/full.chain.key.store.p12" \
        -srcalias "${4}" \
        -srcstoretype PKCS12 \
        -destalias "${4}" \
        -srcstorepass "${3}" \
        -deststorepass "${3}"
      local _l_res_ed25519=$?
      if [ ${_l_res_ed25519} -ne 0 ]; then
        pu_log_e "CRTMGR|32| Failed to import RSA key store for subject ${2}"
        _l_error_count=$((_l_error_count+1))
      fi
    fi

  return ${_l_error_count}
}

#### Public functions 51+
# Function 51 - Assures all artifacts for a subject are in place
cert_mgr_manage_subject(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  # $2 subject folder name (no path, no slashes)

  if [ ! -d "${1}/${2}" ]; then
    pu_log_e "CRTMGR|51| Subject folder ${1}/${2} does not exist"
    return 101
  fi
  mkdir -p "${1}/${2}/out/rsa" "${1}/${2}/out/ed25519"

  if [ -f "${1}/${2}/set-env.sh" ]; then
    pu_log_d "CRTMGR|51| Sourcing existing ${1}/${2}/set-env.sh"
    # shellcheck disable=SC1090
    . "${1}/${2}/set-env.sh"
  else
    pu_log_i "CRTMGR|51| No ${1}/${2}/set-env.sh file to source"
  fi

  _cert_mgr_assure_passphrase_for_subject "${1}" "${2}"
  local _l_subject_passphrase="${CRTMGR_PK_PASS}"
  unset CRTMGR_PK_PASS

  local _l_error_count=0
  _cert_mgr_assure_keys_for_subject "${1}" "${2}" "${_l_subject_passphrase}" || _l_error_count=$((_l_error_count+1))

  if [ "${CRTMGR_SUBJECT_TYPE}" = "RootCA" ]; then
    # in case of Root CA only the self signed certificate is needed, without CSRs and the other bundled constructs
    _cert_mgr_assure_root_ca_cert "${1}" "${2}" "${_l_subject_passphrase}" || _l_error_count=$((_l_error_count+1))
  else
    _cert_mgr_assure_csr_for_subject "${1}" "${2}" "${_l_subject_passphrase}" || _l_error_count=$((_l_error_count+1))
    _cert_mgr_assure_cert_for_subject "${1}" "${2}" || _l_error_count=$((_l_error_count+1))
    _cert_mgr_assure_key_cert_bundles_for_subject "${1}" "${2}" || _l_error_count=$((_l_error_count+1))
    _cert_mgr_assure_pkcs12_private_keys_store_for_subject \
      "${1}" "${2}" \
      "${_l_subject_passphrase}" \
      "${CRTMGR_SIGNING_CA_SUBJECT_DIR}" \
      || _l_error_count=$((_l_error_count+1))
    _cert_mgr_assure_pkcs12_private_keys_store_with_chain_for_subject \
      "${1}" "${2}" \
      "${_l_subject_passphrase}" \
      "${CRTMGR_SIGNING_CA_SUBJECT_DIR}" \
      "" "${CRTMGR_KEY_STORE_ENTRY_NAME}" \
      || _l_error_count=$((_l_error_count+1))

    _cert_mgr_assure_pkcs12_trust_store_for_subject \
      "${1}" "${2}" "${CRTMGR_KEY_STORE_ENTRY_NAME}" || _l_error_count=$((_l_error_count+1))

    _cert_mgr_assure_simple_jks_truststore_for_subject \
      "${1}" "${2}" "${CRTMGR_KEY_STORE_ENTRY_NAME}" || _l_error_count=$((_l_error_count+1))

    _cert_mgr_assure_full_chain_jks_keystore_for_subject \
      "${1}" "${2}" "${_l_subject_passphrase}" "${CRTMGR_KEY_STORE_ENTRY_NAME}" \
      || _l_error_count=$((_l_error_count+1))
  fi

  # Important: ensure these variables do not re-enter for another subject
  unset CRTMGR_PK_PASS CRTMGR_SUBJECT_TYPE CRTMGR_SIGNING_CA_SUBJECT_DIR
  if [ ${_l_error_count} -ne 0 ]; then
    pu_log_e "CRTMGR|52| Errors detected while managing subject ${1}/${2}!"
    return 1
  fi
  return 0
}

# Function 52 - manages all subjects in a folder
cert_mgr_manage_all_subjects(){
  # Params
  # $1 subjects folder name (full path, no trailing slashes)
  pu_log_i "CRTMGR|52| Managing all subjects in folder ${1} ..."
  if [ ! -d "${1}" ]; then
    pu_log_e "CRTMGR|52| Subjects folder ${1} does not exist!"
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
