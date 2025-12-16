FROM docker.io/arm64v8/ubuntu:24.04

# Try matching GitHub Actions environment plus build tools

# hadolint ignore=DL3008
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        bc \
        bison \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        dos2unix \
        flex \
        gcc-aarch64-linux-gnu \
        git-core \
        libncurses-dev \
        libssl-dev \
        pkg-config \
        python3-pip \
        python3-setuptools \
        python3-venv \
        python3-wheel \
        squashfs-tools \
        unzip \
        wget \
        && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
