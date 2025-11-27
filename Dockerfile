FROM docker:24-dind

# Install dependencies (bash, curl, git, jq, libc, etc.)
RUN apk update && apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    openssl \
    sudo \
    icu-libs \
    libstdc++ \
    tini

# Install glibc for running Azure DevOps agent (requires glibc loader and symbols like __isnan/__isnanf)
# Using sgerrand/alpine-pkg-glibc packages
# Note: Alpine 3.20 images often include gcompat which conflicts with glibc (both provide ld-linux-x86-64.so.2).
# Remove gcompat before installing glibc to avoid file ownership conflicts.
ENV GLIBC_VERSION=2.35-r1
RUN set -eux; \
    apk del --no-cache gcompat || true; \
    curl -fsSL -o /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub; \
    curl -fsSL -o /tmp/glibc.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk; \
    curl -fsSL -o /tmp/glibc-bin.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk; \
    apk add --no-cache --allow-untrusted --force-overwrite /tmp/glibc.apk /tmp/glibc-bin.apk; \
    rm -f /tmp/glibc.apk /tmp/glibc-bin.apk

# Create agent user
RUN adduser -D -u 1000 azuredevops && \
    addgroup azuredevops docker && \
    adduser azuredevops docker

USER azuredevops
WORKDIR /azp

ENV AZP_AGENTPACKAGE=https://download.agent.dev.azure.com/agent/4.264.2/vsts-agent-linux-x64-4.264.2.tar.gz

RUN curl -LsS "$AZP_AGENTPACKAGE" | tar -xz

ENV RUNNER_ALLOW_RUNASROOT=1
# Copy start script
USER root
COPY start.sh /azp/start.sh
RUN chmod +x /azp/start.sh

# Docker-in-Docker setup
# dind entrypoint is from base image, we wrap it with tini and our script
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["sh", "-c", "dockerd-entrypoint.sh & /azp/start.sh"]
