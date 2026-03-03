#!/bin/sh
#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#
# FTP Test Client - Scenarios
#
# Two scenarios executed in sequence via shunit2:
#
#   Scenario 1 - Transfer round trip with checksum
#     - Checks server port reachability
#     - Prepares a random file and computes its sha256
#     - Logs in as primary user (fail if unsuccessful)
#     - Audits remote state before and after upload
#     - Uploads the file
#     - Downloads the file under a different name
#     - Asserts checksums match
#
#   Scenario 2 - Get only from read-only folder (follows scenario 1)
#     - Logs in as secondary (read-only) user (fail if unsuccessful)
#     - Audits remote state
#     - Downloads the file uploaded in scenario 1 under a different name
#     - Asserts checksums match
#
# Configuration via environment variables (see ft-test-client-functions.sh):
#   FTC_KEY_TYPE       - rsa | ed25519 | <future>           (default: rsa)
#   FTC_PROTOCOL       - ftp | ftps | ftps-implicit | sftp  (default: sftp)
#                        ftps         = explicit TLS, port 21, AUTH TLS upgrade
#                        ftps-implicit = implicit TLS, port 990, TLS from connect
#   FTC_TRANSFER_MODE  - binary | text                      (default: binary)
#   FTC_HOST           - server hostname            (default: ft-test-double)
#   FTC_PORT           - server port (empty = protocol default)
#   FTC_USER           - primary user               (default: ftuser01)
#   FTC_PASS           - primary password           (default: Manage01)
#   FTC_RO_USER        - read-only user             (default: ftuser02)
#   FTC_RO_PASS        - read-only password         (default: Manage01)
#   FTC_REMOTE_UPLOAD_DIR  - remote upload dir      (default: private)
#   FTC_REMOTE_RO_DIR      - remote read-only dir   (default: /home/<FTC_USER>/shared)
#   FTC_WORK_DIR       - local temp dir             (default: /tmp/ftc-work)

# shellcheck disable=SC3043

# ─── Bootstrap ──────────────────────────────────────────────────────────────

# Resolve the directory where this script lives so we can source siblings
_FTS_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source the function library (which also bootstraps PU)
# shellcheck source=ft-test-client-functions.sh
. "${_FTS_SCRIPT_DIR}/ft-test-client-functions.sh"

# ─── Shared state between scenarios ─────────────────────────────────────────

# These are set by scenario 1 and consumed by scenario 2
_FTS_UPLOADED_FILENAME=""   # basename of the file uploaded in scenario 1
_FTS_ORIGINAL_CHECKSUM=""   # sha256 of the file prepared in scenario 1

# ─── setUp / tearDown ────────────────────────────────────────────────────────

oneTimeSetUp() {
  pu_log_i "FTS| ============================================================"
  pu_log_i "FTS| Test suite starting"
  pu_log_i "FTS| FTC_KEY_TYPE      = ${FTC_KEY_TYPE}"
  pu_log_i "FTS| FTC_PROTOCOL      = ${FTC_PROTOCOL}"
  pu_log_i "FTS| FTC_TRANSFER_MODE = ${FTC_TRANSFER_MODE}"
  pu_log_i "FTS| FTC_HOST          = ${FTC_HOST}"
  pu_log_i "FTS| FTC_USER          = ${FTC_USER}"
  pu_log_i "FTS| FTC_RO_USER       = ${FTC_RO_USER}"
  pu_log_i "FTS| ============================================================"
  mkdir -p "${FTC_WORK_DIR}"
}

oneTimeTearDown() {
  pu_log_i "FTS| ============================================================"
  pu_log_i "FTS| Test suite finished. Cleaning up work dir: ${FTC_WORK_DIR}"
  pu_log_i "FTS| ============================================================"
  rm -rf "${FTC_WORK_DIR}"
}

# ─── Scenario 1: Transfer round trip with checksum ───────────────────────────

test_scenario_01_transfer_round_trip() {
  pu_log_i "FTS|S1| ── Scenario 1: Transfer round trip with checksum ──────────"

  # ── Step 1: Check server port reachability ──────────────────────────────
  pu_log_i "FTS|S1| Step 1: Check server port reachability"
  if ! ftc_check_port; then
    pu_log_e "FTS|S1| Server port not reachable. Failing scenario."
    fail "S1: server port not reachable"
    return
  fi

  # ── Step 2: Prepare a random file and compute its sha256 ────────────────
  pu_log_i "FTS|S1| Step 2: Prepare random file"
  local _l_epoch
  _l_epoch="$(date +%s)"
  local _l_upload_file="${FTC_WORK_DIR}/upload_${_l_epoch}.bin"
  ftc_prepare_random_file "${_l_upload_file}" 8192

  _FTS_UPLOADED_FILENAME="$(basename "${_l_upload_file}")"
  _FTS_ORIGINAL_CHECKSUM="$(ftc_sha256 "${_l_upload_file}")"
  pu_log_i "FTS|S1| Prepared file   : ${_l_upload_file}"
  pu_log_i "FTS|S1| Original sha256 : ${_FTS_ORIGINAL_CHECKSUM}"

  # ── Step 3: Login check ─────────────────────────────────────────────────
  pu_log_i "FTS|S1| Step 3: Login check (primary user)"
  if ! ftc_login "${FTC_USER}" "${FTC_PASS}"; then
    pu_log_e "FTS|S1| Login failed. Failing scenario."
    fail "S1: login failed for primary user ${FTC_USER}"
    return
  fi

  # ── Step 4: Audit remote state before upload ────────────────────────────
  pu_log_i "FTS|S1| Step 4: Audit remote state (before upload)"
  ftc_audit_remote_state "${FTC_REMOTE_UPLOAD_DIR}" "${FTC_USER}" "${FTC_PASS}"

  # ── Step 5: Upload the file ─────────────────────────────────────────────
  pu_log_i "FTS|S1| Step 5: Upload file"
  if ! ftc_put "${_l_upload_file}" "${FTC_REMOTE_UPLOAD_DIR}" "${FTC_USER}" "${FTC_PASS}"; then
    pu_log_e "FTS|S1| Upload failed. Failing scenario."
    fail "S1: upload failed"
    return
  fi

  # ── Step 6: Audit remote state after upload ─────────────────────────────
  pu_log_i "FTS|S1| Step 6: Audit remote state (after upload)"
  ftc_audit_remote_state "${FTC_REMOTE_UPLOAD_DIR}" "${FTC_USER}" "${FTC_PASS}"

  # ── Step 7: Download the file under a different name ────────────────────
  pu_log_i "FTS|S1| Step 7: Download file under a different name"
  local _l_download_file="${FTC_WORK_DIR}/download_${_l_epoch}.bin"
  local _l_remote_path="${FTC_REMOTE_UPLOAD_DIR}/${_FTS_UPLOADED_FILENAME}"

  if ! ftc_get "${_l_remote_path}" "${_l_download_file}" "${FTC_USER}" "${FTC_PASS}"; then
    pu_log_e "FTS|S1| Download failed. Failing scenario."
    fail "S1: download failed"
    return
  fi

  # ── Step 8: Compute checksum of downloaded file ─────────────────────────
  pu_log_i "FTS|S1| Step 8: Compute checksum of downloaded file"
  local _l_download_checksum
  _l_download_checksum="$(ftc_sha256 "${_l_download_file}")"
  pu_log_i "FTS|S1| Downloaded sha256: ${_l_download_checksum}"

  # ── Step 9: Assert checksums match ──────────────────────────────────────
  pu_log_i "FTS|S1| Step 9: Assert checksums match"
  if ! ftc_assert_checksum "${_FTS_ORIGINAL_CHECKSUM}" "${_l_download_file}"; then
    pu_log_e "FTS|S1| Checksum mismatch. Failing scenario."
    fail "S1: checksum mismatch after round trip"
    return
  fi

  pu_log_i "FTS|S1| ── Scenario 1 PASSED ──────────────────────────────────────"
  assertTrue "S1: transfer round trip with checksum" "true"
}

# ─── Scenario 2: Get only from read-only folder ──────────────────────────────

test_scenario_02_get_from_readonly_folder() {
  pu_log_i "FTS|S2| ── Scenario 2: Get only from read-only folder ─────────────"

  # Guard: scenario 2 depends on scenario 1 having uploaded a file
  if [ -z "${_FTS_UPLOADED_FILENAME}" ] || [ -z "${_FTS_ORIGINAL_CHECKSUM}" ]; then
    pu_log_e "FTS|S2| Scenario 1 did not produce upload state. Skipping."
    fail "S2: prerequisite from scenario 1 not met (no uploaded file recorded)"
    return
  fi

  pu_log_i "FTS|S2| File to retrieve : ${_FTS_UPLOADED_FILENAME}"
  pu_log_i "FTS|S2| Expected sha256  : ${_FTS_ORIGINAL_CHECKSUM}"

  # The read-only user accesses the file via the shared/read-only path.
  # The harness is expected to configure the server so that FTC_RO_USER
  # can read from FTC_REMOTE_RO_DIR, which contains the file uploaded
  # by the primary user in scenario 1.
  local _l_remote_ro_path="${FTC_REMOTE_RO_DIR}/${_FTS_UPLOADED_FILENAME}"

  # ── Step 1: Login check (read-only user) ────────────────────────────────
  pu_log_i "FTS|S2| Step 1: Login check (read-only user)"
  if ! ftc_login "${FTC_RO_USER}" "${FTC_RO_PASS}"; then
    pu_log_e "FTS|S2| Login failed for read-only user. Failing scenario."
    fail "S2: login failed for read-only user ${FTC_RO_USER}"
    return
  fi

  # ── Step 2: Audit remote state ──────────────────────────────────────────
  pu_log_i "FTS|S2| Step 2: Audit remote state (read-only user)"
  ftc_audit_remote_state "${FTC_REMOTE_RO_DIR}" "${FTC_RO_USER}" "${FTC_RO_PASS}"

  # ── Step 3: Download the file under a different name ────────────────────
  pu_log_i "FTS|S2| Step 3: Download file under a different name"
  local _l_epoch
  _l_epoch="$(date +%s)"
  local _l_ro_download_file="${FTC_WORK_DIR}/ro_download_${_l_epoch}.bin"

  if ! ftc_get "${_l_remote_ro_path}" "${_l_ro_download_file}" "${FTC_RO_USER}" "${FTC_RO_PASS}"; then
    pu_log_e "FTS|S2| Download failed for read-only user. Failing scenario."
    fail "S2: download failed for read-only user"
    return
  fi

  # ── Step 4: Compute checksum of downloaded file ─────────────────────────
  pu_log_i "FTS|S2| Step 4: Compute checksum of downloaded file"
  local _l_ro_checksum
  _l_ro_checksum="$(ftc_sha256 "${_l_ro_download_file}")"
  pu_log_i "FTS|S2| Downloaded sha256: ${_l_ro_checksum}"

  # ── Step 5: Assert checksums match ──────────────────────────────────────
  pu_log_i "FTS|S2| Step 5: Assert checksums match"
  if ! ftc_assert_checksum "${_FTS_ORIGINAL_CHECKSUM}" "${_l_ro_download_file}"; then
    pu_log_e "FTS|S2| Checksum mismatch. Failing scenario."
    fail "S2: checksum mismatch for read-only download"
    return
  fi

  pu_log_i "FTS|S2| ── Scenario 2 PASSED ──────────────────────────────────────"
  assertTrue "S2: get from read-only folder" "true"
}

# ─── shunit2 entry point ─────────────────────────────────────────────────────
# shellcheck source=/dev/null
. shunit2

# Made with Bob