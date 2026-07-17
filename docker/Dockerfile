FROM ghcr.io/openxiangshan/xs-env:ubuntu-24.04

ARG AE_UID=1000
ARG AE_GID=1000

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      binutils-riscv64-unknown-elf \
      build-essential \
      ca-certificates \
      curl \
      device-tree-compiler \
      gcc-riscv64-unknown-elf \
      git \
      openjdk-17-jdk-headless \
      pkg-config \
      python3 \
      python3-matplotlib \
      tar \
      time \
      zlib1g-dev \
      libzstd-dev && \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    if ! getent group "${AE_GID}" >/dev/null; then \
      groupadd --gid "${AE_GID}" "hola-ae-g${AE_GID}"; \
    fi; \
    if ! getent passwd "${AE_UID}" >/dev/null; then \
      useradd --uid "${AE_UID}" --gid "${AE_GID}" --no-create-home \
        --home-dir /home/hola-ae --shell /bin/bash "hola-ae-u${AE_UID}"; \
    fi; \
    mkdir -p /home/hola-ae/.cache; \
    chown -R "${AE_UID}:${AE_GID}" /home/hola-ae

ENV HOME=/home/hola-ae
ENV XDG_CACHE_HOME=/home/hola-ae/.cache

USER ${AE_UID}:${AE_GID}
WORKDIR /ae
