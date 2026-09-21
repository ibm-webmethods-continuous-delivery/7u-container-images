ARG __edge_image=iwhicr.azurecr.io/webmethods-edge-runtime:12.0.6.0

FROM ${__edge_image} AS wmpcli

ARG __guest_wm_home=/opt/webmethods
ARG __guest_is_home=${__guest_wm_home}/IntegrationServer

# Secret is mounted at /run/secrets/wpm_token and never written to any layer.
# mode=0444 allows the non-root sagadmin user to read it (default 0400 is root-only).
RUN --mount=type=secret,id=wpm_token,mode=0444 \
    test -s /run/secrets/wpm_token || { echo "YOU MUST SET --secret id=wpm_token"; exit 1; } && \
    ${__guest_wm_home}/wpm/bin/wpm.sh install WmJDBCAdapter \
        -d ${__guest_is_home} \
        -wr licensed \
        -ad true \
        -j "$(cat /run/secrets/wpm_token)"

FROM ${__edge_image}

ARG __guest_wm_home=/opt/webmethods
ARG __guest_is_home=${__guest_wm_home}/IntegrationServer

COPY --from=wmpcli --chown=sagadmin:root ${__guest_is_home}/packages/WmJDBCAdapter/ ${__guest_is_home}/packages/WmJDBCAdapter/
