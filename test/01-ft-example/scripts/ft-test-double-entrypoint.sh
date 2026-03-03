#!/bin/sh
#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#
# FTP Test Double Entrypoint Script
#
# Environment variables (set per service in docker-compose.yml):
#   FT_TLS_MODE       - classical | pq-hybrid  (controls OpenSSL provider)
#   FT_SFTP_KEY_TYPE  - rsa | ed25519          (controls SFTP host key)
#   CRTMGR_PK_PASS    - passphrase for encrypted private keys from cert-manager

set -e

echo "Preparing FTP server (TLS_MODE=${FT_TLS_MODE}, SFTP_KEY_TYPE=${FT_SFTP_KEY_TYPE})..."

# Source function library
. /opt/ft-test-double/scripts/ft-test-double-functions.sh

# ─── Runtime key staging area ────────────────────────────────────────────────
# /etc/proftpd/certs/rsa and /etc/proftpd/ssh are read-only bind mounts
# (source files from cert-manager on the host). All runtime-generated or
# decrypted key files go to /tmp/proftpd-keys/ which is writable.
# proftpd.conf references these /tmp paths via the FT_KEYS_DIR env var,
# or directly as /tmp/proftpd-keys/*.
_KEYS_DIR="/tmp/proftpd-keys"
mkdir -p "${_KEYS_DIR}"

# ProFTPD runtime directories (scoreboard, delay table, control socket)
mkdir -p /run/proftpd

# ─── Step 1: Decrypt RSA private key for TLS/FTPS ────────────────────────────
echo "Decrypting RSA private key for TLS/FTPS..."
openssl rsa \
  -in /etc/proftpd/certs/rsa/private.encrypted.keypair.pem \
  -passin "pass:${CRTMGR_PK_PASS}" \
  -out "${_KEYS_DIR}/tls.rsa.key.pem"
chmod 600 "${_KEYS_DIR}/tls.rsa.key.pem"

# ─── Step 2: Configure SFTP host keys ────────────────────────────────────────
echo "Configuring SFTP host keys (key type: ${FT_SFTP_KEY_TYPE})..."

# Always generate an RSA host key (ProFTPD mod_sftp requires at least one)
ssh-keygen -t rsa -b 2048 -f "${_KEYS_DIR}/ssh_host_rsa_key" -N '' -q

if [ "${FT_SFTP_KEY_TYPE}" = "ed25519" ]; then
  echo "  Generating ED25519 host key (ProFTPD mod_sftp requires OpenSSH native format)..."
  # ProFTPD mod_sftp only supports OpenSSH-format ED25519 keys, not PEM/PKCS#8.
  # The cert-manager generates PEM format, which Alpine's ssh-keygen can't convert.
  # Solution: generate a fresh ED25519 key (ssh-keygen outputs OpenSSH format by default).
  # Note: ED25519 is not quantum-resistant; pq-hybrid mode's quantum hardening is in
  # the TLS KEX (x25519_kyber768), not the SFTP host key.
  ssh-keygen -t ed25519 -f "${_KEYS_DIR}/ssh_host_ed25519_key" -N '' -q
  chmod 600 "${_KEYS_DIR}/ssh_host_ed25519_key"
else
  echo "  RSA-only SFTP mode; generating placeholder ED25519 host key..."
  # proftpd.conf always references the ED25519 host key path.
  # In RSA-only mode we still generate a key so ProFTPD can start;
  # the classical service uses RSA as its primary host key.
  ssh-keygen -t ed25519 -f "${_KEYS_DIR}/ssh_host_ed25519_key" -N '' -q
  chmod 600 "${_KEYS_DIR}/ssh_host_ed25519_key"
fi

# ─── Step 3: Install client public keys for SFTP key-based auth ──────────────
# The cert-manager generates client key pairs and places the public keys at:
#   /run/secrets/ft-client-keys/rsa/id_client.pub
#   /run/secrets/ft-client-keys/ed25519/id_client.pub
#
# We install them into each user's authorized_keys so the test client can
# authenticate with key-based auth (no password needed for SFTP scenarios).

echo "Installing client public keys for SFTP key-based auth..."

for _user in ftuser01 ftuser02; do
  _ssh_dir="/home/${_user}/.ssh"
  mkdir -p "${_ssh_dir}"
  # IMPORTANT: ProFTPD (running as user 'ftpd') must be able to traverse into
  # .ssh directory and read authorized_keys for public-key authentication.
  # In production, use group permissions or run ProFTPD as root.
  # For test environment, we use world-readable/executable permissions.
  chmod 755 "${_ssh_dir}"  # World-executable so ProFTPD can traverse into it

  _auth_keys="${_ssh_dir}/authorized_keys"
  : > "${_auth_keys}"   # truncate / create

  for _key_type in rsa ed25519; do
    _pub_key="/run/secrets/ft-client-keys/${_key_type}/id_client.pub"
    if [ -f "${_pub_key}" ]; then
      # ProFTPD mod_sftp requires RFC4716 format
      # Convert to RFC4716 and append to authorized_keys
      ssh-keygen -e -f "${_pub_key}" >> "${_auth_keys}"
      echo "  Installed ${_key_type} public key for ${_user} (RFC4716 format)"
    else
      echo "  WARNING: ${_pub_key} not found; skipping ${_key_type} for ${_user}"
    fi
  done

  chmod 644 "${_auth_keys}"  # World-readable so ProFTPD (running as ftpd) can read it
done

# Fix ownership after writing
chown -R ftuser01:ftuser01grp /home/ftuser01/.ssh
chown -R ftuser02:ftuser02grp /home/ftuser02/.ssh

# ─── Step 4: Set up user home directories ────────────────────────────────────
# Note: /home/ftuser02/shared is mounted read-only (shared volume from ftuser01).
# We must NOT chown or chmod it. Only touch the writable parts of each home.
echo "Setting up user directories..."
mkdir -p /home/ftuser01/private /home/ftuser01/shared
mkdir -p /home/ftuser02/private
# ftuser01: own the entire home (shared is a writable named volume for ftuser01)
chown ftuser01:ftuser01grp /home/ftuser01
chown -R ftuser01:ftuser01grp /home/ftuser01/private
chown -R ftuser01:ftuser01grp /home/ftuser01/shared
chmod 755 /home/ftuser01/shared
# ftuser02: own home dir and private subdir only; shared is :ro, skip it
chown ftuser02:ftuser02grp /home/ftuser02
chown -R ftuser02:ftuser02grp /home/ftuser02/private

# ─── Step 5: Fix ProFTPD file permissions ────────────────────────────────────
# ProFTPD security checks:
#   - AuthUserFile/AuthGroupFile must NOT be world-readable (need 0600/0640)
#   - proftpd.conf must NOT be world-writable
#
# On Windows bind mounts, files appear as 0777 to Linux regardless of :ro flag.
# We cannot chmod a :ro bind mount. Solution: copy config to /tmp with safe perms.
#
# ftppasswd and ftpgroup are in the image (not bind-mounted), so chmod works.
echo "Fixing ProFTPD file permissions..."
chmod 600 /etc/proftpd/ftppasswd /etc/proftpd/ftpgroup

# Copy the bind-mounted (world-writable on Windows) config to a writable location
# and set safe permissions so ProFTPD accepts it.
cp /etc/proftpd/proftpd.conf /tmp/proftpd.conf
chmod 640 /tmp/proftpd.conf

# ─── Step 6: Start ProFTPD ────────────────────────────────────────────────────
echo "Starting ProFTPD (TLS_MODE=${FT_TLS_MODE})..."
exec proftpd --nodaemon --config /tmp/proftpd.conf

# Made with Bob
