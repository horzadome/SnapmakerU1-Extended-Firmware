FROM docker.io/arm64v8/ubuntu:24.04

# Try matching GitHub Actions environment plus build tools

# hadolint ignore=DL3008
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        build-essential cmake gcc-aarch64-linux-gnu \
        pkg-config squashfs-tools git-core bc libssl-dev \
        curl ca-certificates \
        flex bison libncurses-dev wget unzip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
