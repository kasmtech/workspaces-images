#!/usr/bin/env bash
set -ex
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

# Enable Docker repo
if ! command -v apt-key >/dev/null 2>&1; then
  # apt-key is removed on newer apt releases, use a keyring instead
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > \
    /etc/apt/sources.list.d/docker.list
else
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  echo "deb [arch=${ARCH}] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" > \
    /etc/apt/sources.list.d/docker.list
fi

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
curl -o \
    /usr/local/bin/dind -L \
    https://raw.githubusercontent.com/moby/moby/master/hack/dind
chmod +x /usr/local/bin/dind
curl -o \
    /usr/local/bin/dockerd-entrypoint.sh -L \
    https://kasm-ci.s3.amazonaws.com/dockerd-entrypoint.sh
chmod +x /usr/local/bin/dockerd-entrypoint.sh
echo 'hosts: files dns' > /etc/nsswitch.conf
usermod -aG docker kasm-user

# Install k3d tools
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install kubectl with retry
KUBECTL_VERSION=$(curl -L -s --retry 3 https://dl.k8s.io/release/stable.txt)
for i in 1 2 3; do
    curl -o /usr/local/bin/kubectl -L --retry 3 --retry-delay 5 --connect-timeout 30 \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && break
    echo "kubectl download attempt $i failed, retrying..."
    sleep 5
done
chmod +x /usr/local/bin/kubectl

# Passwordless Sudo
echo 'kasm-user:kasm-user' | chpasswd
echo 'kasm-user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Resolute (26.04) compatibility fixes
# 1. iptables legacy mode - Resolute uses nftables by default, dockerd needs iptables-legacy
update-alternatives --set iptables /usr/sbin/iptables-legacy || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true

# 2. Ensure cgroup v2 compatibility - Resolute removed cgroup v1
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "storage-driver": "fuse-overlayfs",
  "exec-opts": ["native.cgroupdriver=cgroupfs"]
}
EOF

# 3. sudo-rs compatibility - Resolute uses sudo-rs, ensure sudoers works
echo 'kasm-user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/kasm-user
chmod 0440 /etc/sudoers.d/kasm-user

# Cleanup
if [ -z ${SKIP_CLEAN+x} ]; then
    apt-get autoclean
    rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*
fi