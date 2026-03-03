#!/bin/sh
#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#
# FTP Test Client - U-Tier Entry Point
#
# Delegates to the T-tier ft-scenarios.sh script which runs all shunit2
# scenarios for the current combination of FTC_PROTOCOL, FTC_KEY_TYPE,
# FTC_HOST, and FTC_PORT.
#
# In the test harness (01-ft-example), this CMD is overridden by the
# docker-compose command directive which invokes run-scenarios.sh instead,
# iterating all combinations automatically.
#
# When used standalone (single combination), set env vars and run directly:
#   docker run --rm \
#     -e FTC_HOST=ft-test-double-classical \
#     -e FTC_PROTOCOL=sftp \
#     -e FTC_KEY_TYPE=ed25519 \
#     ft-test-client-u:alpine

exec sh "${FTC_PROVIDED_SCRIPTS_HOME}/ft-scenarios.sh"

# Made with Bob
