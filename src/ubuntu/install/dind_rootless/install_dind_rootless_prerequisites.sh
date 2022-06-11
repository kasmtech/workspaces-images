#!/usr/bin/env bash
set -ex

apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    dbus-user-session \
    fuse-overlayfs \
    kmod \
    iptables \
    openssh-client \
    uidmap \
    wget \
    slirp4netns \
    pigz \
    xz-utils \
    iproute2 \
    xfsprogs \
    btrfs-progs \
    e2fsprogs && \
rm -rf /var/lib/apt/list/*