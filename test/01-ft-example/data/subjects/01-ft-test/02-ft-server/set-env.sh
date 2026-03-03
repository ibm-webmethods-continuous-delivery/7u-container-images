#!/bin/sh
#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#
# FTP Test Server Certificate

export CRTMGR_SUBJECT_TYPE="Server"
export CRTMGR_SUBJ_PARAM="/CN=FT\ Test\ Server"
export CRTMGR_KEY_STORE_ENTRY_NAME="ft-test-server"
export CRTMGR_CERTIFICATE_VALIDITY_DAYS=365
export CRTMGR_SIGNING_CA_SUBJECT_DIR="01-ca-ft-test"

# Passphrase: resolved from the harness-level TEST_PK_SECRET env var.
# TEST_PK_SECRET is set in docker-compose for unattended CI/CD operation.
# In production, do not use a shared env var; use a proper secrets manager.
export CRTMGR_PK_PASS="${TEST_PK_SECRET}"

# Made with Bob
