# syntax=docker/dockerfile:1
ARG __edge_image=iwcd-edge-debug:latest

FROM iwcd-edge-debug:latest AS wmpcli

ARG __guest_is_home=/opt/webmethods/IntegrationServer

# Secret is mounted at /run/secrets/wpm_token and never written to any layer.
# mode=0444 allows the non-root sagadmin user to read it (default 0400 is root-only).
RUN --mount=type=secret,id=wpm_token,mode=0444 \
    test -s /run/secrets/wpm_token || { echo "YOU MUST SET --secret id=wpm_token"; exit 1; } && \
    /opt/webmethods/wpm/bin/wpm.sh install WmJDBCAdapter \
        -d /opt/webmethods/IntegrationServer \
        -wr licensed \
        -j "$(cat /run/secrets/wpm_token)"

FROM ${__edge_image}

ARG __guest_is_home=/opt/webmethods/IntegrationServer

COPY --from=wmpcli --chown=sagadmin:root ${__guest_is_home}/packages/WmJDBCAdapter/ ${__guest_is_home}/packages/WmJDBCAdapter/
