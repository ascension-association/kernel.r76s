FROM debian:trixie

RUN apt-get update && apt-get install -y --no-install-recommends \
    bc bison build-essential ca-certificates cpio device-tree-compiler flex \
    git kmod libelf-dev libgnutls28-dev libssl-dev python3 python3-dev \
    python3-pyelftools python3-setuptools rsync swig uuid-dev wget xz-utils \
 && if [ "$(dpkg --print-architecture)" != "arm64" ]; then \
      apt-get install -y --no-install-recommends crossbuild-essential-arm64; \
    fi \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src
