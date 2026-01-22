@echo off

REM Copyright 2026 IBM Corporation
REM SPDX-License-Identifier: Apache-2.0

docker buildx build -t vm-emu-minimal-s:ubi9 .
