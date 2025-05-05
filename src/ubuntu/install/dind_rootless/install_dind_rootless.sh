#!/usr/bin/env bash
set -ex

# Enable Docker repo
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
echo "deb [arch=${ARCH}] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" > \
    /etc/apt/sources.list.d/docker.list

# Install deps
apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    dbus-user-session \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    fuse-overlayfs \
    iptables \
    kmod \
    openssh-client \
    sudo \
    supervisor \
    uidmap \
    wget

# URLs
STABLE_LATEST=$(curl -sL https://get.docker.com/rootless | awk -F'="' '/STABLE_LATEST=/ {print substr($2, 1, length($2)-1)}')
STATIC_RELEASE_ROOTLESS_URL="https://download.docker.com/linux/static/stable/$(uname -m)/docker-rootless-extras-${STABLE_LATEST}.tgz"

# User settings
curl -o \
    /usr/local/bin/dind -L \
    https://raw.githubusercontent.com/moby/moby/master/hack/dind
chmod +x /usr/local/bin/dind
echo 'hosts: files dns' > /etc/nsswitch.conf

# Install rootless extras
curl -o \
  /tmp/rootless.tgz -L \
  "${STATIC_RELEASE_ROOTLESS_URL}"
tar -xf \
  /tmp/rootless.tgz \
  --strip-components 1 \
  --directory /usr/local/bin/ \
  'docker-rootless-extras/dockerd-rootless.sh' \
  'docker-rootless-extras/rootlesskit' \
  'docker-rootless-extras/vpnkit'

# Cleanup
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi
