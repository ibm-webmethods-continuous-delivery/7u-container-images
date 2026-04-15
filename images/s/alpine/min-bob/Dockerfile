ARG __alpine_version=3.23
FROM alpine:${__alpine_version} AS stage1

############## Part 1 - bring the prerequisites
# Alpine packages and versions: https://pkgs.alpinelinux.org/

RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      bash \
      curl \
      icu-data-full \
      npm \
    && curl -sSL https://s3.us-south.cloud-object-storage.appdomain.cloud/bobshell/install-bobshell.sh | bash

FROM alpine:${__alpine_version}

## Purpose: as little software as possible to make Bob work
## Expect to mount user home and workspace, keep root fs read-only

# Bob requires bash and internationalization
# We do not agree with this hadolint rule for Alpine or any other distro that only works with the latest version of a package.
# hadolint ignore=DL3018,DL4006
RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      bash \
      icu-data-full

COPY --from=stage1 /usr/local/bin/ /usr/local/bin/
COPY --from=stage1 /usr/local/lib/ /usr/local/lib/
