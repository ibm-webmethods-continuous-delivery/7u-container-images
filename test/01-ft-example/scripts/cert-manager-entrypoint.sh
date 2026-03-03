#!/bin/sh
#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#
# Certificate Manager Entrypoint Script
#
# Generates:
#   1. Server TLS certificates (RSA + ED25519) via cert-manager
#   2. Client SSH key pairs (RSA + ED25519) for SFTP key-based auth

set -e

echo "Starting certificate manager..."

# Guard: TEST_PK_SECRET must be set for unattended operation.
# Each subject's set-env.sh resolves CRTMGR_PK_PASS from this variable.
# Without it, the cert-manager function library falls back to pu_read_secret_from_user
# (interactive terminal prompt), which blocks unattended CI/CD execution.
if [ -z "${TEST_PK_SECRET}" ]; then
  echo "[FATAL] TEST_PK_SECRET is not set. Set it in docker-compose environment for unattended operation." >&2
  exit 1
fi

# Source initialization scripts
. /opt/cert-mgr/util/PU_HOME/code/1.init.sh
. /opt/cert-mgr/cert-mgmt-functions.sh

# ─── Step 1: Server TLS certificates ─────────────────────────────────────────
# Call cert_mgr_manage_subject explicitly for each PKI subject.
# We do NOT use cert_mgr_manage_all_subjects because the subjects folder also
# contains non-PKI directories (e.g. 03-ft-client-keys for SSH key pairs)
# that have no set-env.sh and would cause manage_all_subjects to fail.
#
# cert_mgr_manage_all_subjects normally deletes the global trust store files
# at the start of each run to ensure idempotency. Since we bypass it, we must
# do that cleanup ourselves — otherwise keytool fails with "alias already exists"
# on the second and subsequent runs (data/subjects is a bind mount, not a volume).
echo "Cleaning up global trust store artifacts from previous run..."
mkdir -p /mnt/data/certmgr/01-ft-test/out
rm -f \
  /mnt/data/certmgr/01-ft-test/out/all_certs.pem \
  /mnt/data/certmgr/01-ft-test/out/global.public.trust.store.jks \
  /mnt/data/certmgr/01-ft-test/out/global.public.trust.store.p12

echo "Generating server TLS certificates..."
cert_mgr_manage_subject /mnt/data/certmgr/01-ft-test 01-ca-ft-test
cert_mgr_manage_subject /mnt/data/certmgr/01-ft-test 02-ft-server

# ─── Step 2: Client SSH key pairs ────────────────────────────────────────────
# These are used by ft-test-client for SFTP key-based authentication.
# The public keys must be registered in the server's authorized_keys.
#
# Output layout:
#   /mnt/data/certmgr/01-ft-test/03-ft-client-keys/rsa/id_client
#   /mnt/data/certmgr/01-ft-test/03-ft-client-keys/rsa/id_client.pub
#   /mnt/data/certmgr/01-ft-test/03-ft-client-keys/ed25519/id_client
#   /mnt/data/certmgr/01-ft-test/03-ft-client-keys/ed25519/id_client.pub

_CLIENT_KEYS_DIR="/mnt/data/certmgr/01-ft-test/03-ft-client-keys"

echo "Generating client SSH key pairs..."

# RSA client key
_RSA_DIR="${_CLIENT_KEYS_DIR}/rsa"
mkdir -p "${_RSA_DIR}"
# Always regenerate to ensure consistency (test environment, idempotency)
rm -f "${_RSA_DIR}/id_client" "${_RSA_DIR}/id_client.pub"
ssh-keygen -t rsa -b 2048 -f "${_RSA_DIR}/id_client" -N '' -q -C "ft-test-client-rsa"
echo "  RSA client key generated: ${_RSA_DIR}/id_client"

# ED25519 client key
_ED25519_DIR="${_CLIENT_KEYS_DIR}/ed25519"
mkdir -p "${_ED25519_DIR}"
# Always regenerate to ensure consistency (test environment, idempotency)
rm -f "${_ED25519_DIR}/id_client" "${_ED25519_DIR}/id_client.pub"
ssh-keygen -t ed25519 -f "${_ED25519_DIR}/id_client" -N '' -q -C "ft-test-client-ed25519"
echo "  ED25519 client key generated: ${_ED25519_DIR}/id_client"

# Ensure keys have appropriate permissions
# Private keys: 0644 (world-readable) for test environment compatibility.
# In production, use 0600 and ensure UID/GID alignment between key owner and consumer.
# Public keys: 0644 (world-readable) as standard for SSH public keys.
chmod 644 "${_RSA_DIR}/id_client" "${_ED25519_DIR}/id_client"
chmod 644 "${_RSA_DIR}/id_client.pub" "${_ED25519_DIR}/id_client.pub"

echo "Certificate and key generation complete."

# Keep container running for inspection
echo "Container will stay running for inspection. Use 'docker exec' to inspect files."
sleep infinity

# Made with Bob
