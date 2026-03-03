ARG __base_image=ft-test-client-t:alpine
FROM ${__base_image}

#
# Copyright IBM Corp. 2026 - 2026
# SPDX-License-Identifier: Apache-2.0
#

# Non-root user for test execution
ARG __test_user_id=1000
ARG __test_user_name=tester
ARG __test_group_gid=1000
ARG __test_group_name=tester

# Test directories
ENV FT_TESTS_HOME=/tests \
    FT_RESULTS_HOME=/results

# Create non-root user
RUN addgroup -g "${__test_group_gid}" "${__test_group_name}" \
    && adduser -D -u "${__test_user_id}" \
        -G "${__test_group_name}" \
        -h /home/${__test_user_name} \
        "${__test_user_name}" \
    && mkdir -p ${FT_TESTS_HOME} ${FT_RESULTS_HOME} \
    && chown -R ${__test_user_id}:${__test_group_gid} \
        ${FT_TESTS_HOME} ${FT_RESULTS_HOME}

# Copy test orchestration scripts
COPY --chown=${__test_user_id}:${__test_group_gid} tests/ ${FT_TESTS_HOME}/
RUN chmod +x ${FT_TESTS_HOME}/*.sh

USER ${__test_user_name}
WORKDIR ${FT_TESTS_HOME}

# Default: run all tests
CMD ["/tests/run-all-tests.sh"]