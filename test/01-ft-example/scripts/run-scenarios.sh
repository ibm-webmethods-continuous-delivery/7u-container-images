#!/bin/sh
#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#
# FT Test Harness - Scenario Runner
#
# Runs all protocol/key-type combinations against both test-double services
# (classical and post-quantum), executing the shunit2 scenarios for each.
#
# Combination matrix:
#
#   Server              | Protocol      | Key type  | Notes
#   --------------------|---------------|-----------|---------------------------
#   ft-test-double-classical | ftp      | (n/a)     | plain FTP, no key type
#   ft-test-double-classical | ftps     | (n/a)     | explicit TLS
#   ft-test-double-classical | ftps-implicit | (n/a) | implicit TLS port 2990 (EXPECTED TO FAIL: ProFTPD mod_tls does NOT support implicit FTPS)
#   ft-test-double-classical | sftp     | rsa       | password auth
#   ft-test-double-classical | sftp     | ed25519   | key-based auth (ed25519 key)
#   ft-test-double-pq-hybrid | ftp      | (n/a)     | plain FTP, no key type
#   ft-test-double-pq-hybrid | ftps     | (n/a)     | explicit TLS (PQ hybrid provider)
#   ft-test-double-pq-hybrid | ftps-implicit | (n/a) | implicit TLS port 2990 (EXPECTED TO FAIL: ProFTPD mod_tls does NOT support implicit FTPS)
#   ft-test-double-pq-hybrid | sftp     | rsa       | password auth
#   ft-test-double-pq-hybrid | sftp     | ed25519   | key-based auth (ed25519 key)
#
# For FTP/FTPS protocols, FTC_KEY_TYPE is irrelevant (no SSH keys used).
# We still pass it for logging completeness; the function library ignores it.
#
# Exit code: 0 if all combinations pass, 1 if any combination fails.

# shellcheck disable=SC3043

set -e

# ─── Bootstrap PU ────────────────────────────────────────────────────────────
if [ -z "${PU_HOME}" ]; then
  echo "[FATAL] PU_HOME is not set." >&2
  exit 1
fi
. "${PU_HOME}/code/1.init.sh"

# ─── Locate the scenarios script ─────────────────────────────────────────────
_RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
_SCENARIOS_SCRIPT="${_RUNNER_DIR}/ft-scenarios.sh"

if [ ! -f "${_SCENARIOS_SCRIPT}" ]; then
  pu_log_e "RUNNER| ft-scenarios.sh not found at: ${_SCENARIOS_SCRIPT}"
  exit 1
fi

# ─── Combination definitions ─────────────────────────────────────────────────
#
# Each combination is encoded as a colon-separated string:
#   <server_label>:<host>:<protocol>:<key_type>:<ftp_port>:<ftps_implicit_port>:<sftp_port>
#
# server_label  - human-readable label for logging
# host          - Docker service hostname
# protocol      - ftp | ftps | ftps-implicit | sftp
# key_type      - rsa | ed25519 | none  (none = not applicable for FTP/FTPS)
# ftp_port      - port for ftp / ftps (explicit TLS)
# ftps_impl_port- port for ftps-implicit
# sftp_port     - port for sftp

_CLASSICAL_HOST="ft-test-double-classical"
_PQ_HYBRID_HOST="ft-test-double-pq-hybrid"

# All combinations: classical server + pq-hybrid server, all protocols
_COMBOS="
classical:${_CLASSICAL_HOST}:ftp:none:2121:2990:2222
classical:${_CLASSICAL_HOST}:ftps:none:2121:2990:2222
classical:${_CLASSICAL_HOST}:ftps-implicit:none:2121:2990:2222
classical:${_CLASSICAL_HOST}:sftp:rsa:2121:2990:2222
classical:${_CLASSICAL_HOST}:sftp:ed25519:2121:2990:2222
pq-hybrid:${_PQ_HYBRID_HOST}:ftp:none:2121:2990:2222
pq-hybrid:${_PQ_HYBRID_HOST}:ftps:none:2121:2990:2222
pq-hybrid:${_PQ_HYBRID_HOST}:ftps-implicit:none:2121:2990:2222
pq-hybrid:${_PQ_HYBRID_HOST}:sftp:rsa:2121:2990:2222
pq-hybrid:${_PQ_HYBRID_HOST}:sftp:ed25519:2121:2990:2222
"

# ─── Counters ─────────────────────────────────────────────────────────────────
_TOTAL=0
_PASSED=0
_FAILED=0
_FAILED_LIST=""

# ─── Run each combination ─────────────────────────────────────────────────────

for _combo in ${_COMBOS}; do
  # Skip blank lines
  [ -z "${_combo}" ] && continue

  # Parse fields
  _server_label="$(echo "${_combo}" | cut -d: -f1)"
  _host="$(echo "${_combo}"         | cut -d: -f2)"
  _protocol="$(echo "${_combo}"     | cut -d: -f3)"
  _key_type="$(echo "${_combo}"     | cut -d: -f4)"
  _ftp_port="$(echo "${_combo}"     | cut -d: -f5)"
  _ftps_impl_port="$(echo "${_combo}" | cut -d: -f6)"
  _sftp_port="$(echo "${_combo}"    | cut -d: -f7)"

  # Resolve effective port for this protocol
  case "${_protocol}" in
    ftp|ftps)          _port="${_ftp_port}"       ;;
    ftps-implicit)     _port="${_ftps_impl_port}"  ;;
    sftp)              _port="${_sftp_port}"        ;;
    *)                 _port="${_ftp_port}"         ;;
  esac

  # Resolve effective key type (none → rsa for env var, but SFTP won't use it)
  _effective_key_type="${_key_type}"
  [ "${_key_type}" = "none" ] && _effective_key_type="rsa"

  _combo_label="${_server_label}/${_protocol}/${_key_type}"
  _TOTAL=$(( _TOTAL + 1 ))

  pu_log_i "RUNNER| ════════════════════════════════════════════════════════"
  pu_log_i "RUNNER| Combination ${_TOTAL}: ${_combo_label}"
  pu_log_i "RUNNER|   host     = ${_host}"
  pu_log_i "RUNNER|   protocol = ${_protocol}"
  pu_log_i "RUNNER|   key_type = ${_key_type}"
  pu_log_i "RUNNER|   port     = ${_port}"
  pu_log_i "RUNNER| ════════════════════════════════════════════════════════"

  # Export env vars consumed by ft-test-client-functions.sh and ft-scenarios.sh
  export FTC_HOST="${_host}"
  export FTC_PORT="${_port}"
  export FTC_PROTOCOL="${_protocol}"
  export FTC_KEY_TYPE="${_effective_key_type}"
  # Work dir is per-combination to avoid cross-contamination
  export FTC_WORK_DIR="/tmp/ftc-work/${_combo_label}"

  # Run the scenarios script; capture exit code without aborting the runner
  set +e
  sh "${_SCENARIOS_SCRIPT}"
  _rc=$?
  set -e

  if [ ${_rc} -eq 0 ]; then
    pu_log_i "RUNNER| ✓ PASSED: ${_combo_label}"
    _PASSED=$(( _PASSED + 1 ))
  else
    pu_log_e "RUNNER| ✗ FAILED: ${_combo_label} (rc=${_rc})"
    _FAILED=$(( _FAILED + 1 ))
    _FAILED_LIST="${_FAILED_LIST}  - ${_combo_label}\n"
  fi

  # Clean up work dir for this combination
  rm -rf "${FTC_WORK_DIR}"
done

# ─── Summary ──────────────────────────────────────────────────────────────────
pu_log_i "RUNNER| ════════════════════════════════════════════════════════"
pu_log_i "RUNNER| Test Run Summary"
pu_log_i "RUNNER|   Total    : ${_TOTAL}"
pu_log_i "RUNNER|   Passed   : ${_PASSED}"
pu_log_i "RUNNER|   Failed   : ${_FAILED}"
pu_log_i "RUNNER| ════════════════════════════════════════════════════════"

if [ ${_FAILED} -gt 0 ]; then
  pu_log_e "RUNNER| FAILED combinations:"
  printf "%b" "${_FAILED_LIST}" | while IFS= read -r _line; do
    pu_log_e "RUNNER| ${_line}"
  done
  exit 1
fi

pu_log_i "RUNNER| ALL COMBINATIONS PASSED"
exit 0

# Made with Bob