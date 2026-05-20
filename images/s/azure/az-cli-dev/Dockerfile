ARG __azure_cli_tag=azurelinux3.0

FROM iwcd-terraform-s:alpine AS terraform

FROM mcr.microsoft.com/azure-cli:${__azure_cli_tag}

RUN tdnf -qy update \
  && tdnf -qy upgrade \
  && tdnf -qy install \
    gettext \
    helm \
    kubectl \
    shadow-utils \
  && tdnf clean all \
  && rm -rf /var/cache/tdnf

COPY --from=terraform /usr/local/bin/ /usr/local/bin/
