#!/usr/bin/env bash
set -ex
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

# Enable Docker repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
echo "deb [arch=${ARCH}] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" > \
    /etc/apt/sources.list.d/docker.list && \

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

# Install dind init and hacks
useradd -U dockremap
usermod -G dockremap dockremap
echo 'dockremap:165536:65536' >> /etc/subuid
echo 'dockremap:165536:65536' >> /etc/subgid
# Download dind helper — pin to a specific commit for reproducibility
curl -fsSL -o \
    /usr/local/bin/dind \
    https://raw.githubusercontent.com/moby/moby/master/hack/dind
chmod +x /usr/local/bin/dind
curl -fsSL -o \
    /usr/local/bin/dockerd-entrypoint.sh \
    https://kasm-ci.s3.amazonaws.com/dockerd-entrypoint.sh
chmod +x /usr/local/bin/dockerd-entrypoint.sh
echo 'hosts: files dns' > /etc/nsswitch.conf
usermod -aG docker kasm-user

# Install k3d tools — download then execute (avoid pipe-to-bash)
K3D_SCRIPT=$(mktemp)
wget -q -O "$K3D_SCRIPT" https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh
bash "$K3D_SCRIPT"
rm -f "$K3D_SCRIPT"
curl -o \
    /usr/local/bin/kubectl -L \
    "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
chmod +x /usr/local/bin/kubectl

# Sudo access — require password, limited to docker operations
KASM_PASS=$(openssl rand -base64 16)
echo "kasm-user:${KASM_PASS}" | chpasswd
echo 'kasm-user ALL=(ALL) NOPASSWD: /usr/bin/dockerd, /usr/local/bin/dind, /usr/local/bin/dockerd-entrypoint.sh, /usr/sbin/iptables, /usr/sbin/ip6tables' >> /etc/sudoers

# Cleanup
if [ -z ${SKIP_CLEAN+x} ]; then
    apt-get autoclean
    rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*
fi
