#!/bin/sh

# Copyright IBM Corporation All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC3043
# SC3043 is about the usage of "local" keyword. While it is not strictly POSIX compliant,
# it works with out current software stack and simplifies our code.

pu_log_i "IWCD|AIO|-- Sourcing IWCD AI Overwatcher commands..."

iwcd_aio_test(){
  pu_log_i "IWCD|AIO|-- Test function called"
}
