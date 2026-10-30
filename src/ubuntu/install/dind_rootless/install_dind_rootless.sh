#!/usr/bin/env bash
set -ex

# Enable Docker repo
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
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
    slirp4netns \
    openssh-client \
    sudo \
    supervisor \
    uidmap \
    wget

# User settings
echo 'hosts: files dns' > /etc/nsswitch.conf

# Passwordless Sudo
echo 'kasm-user:kasm-user' | chpasswd
echo 'kasm-user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Resolute (26.04) compatibility fixes
# 1. iptables legacy mode - Resolute uses nftables by default, dockerd needs iptables-legacy
update-alternatives --set iptables /usr/sbin/iptables-legacy || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true

# 2. Ensure cgroup v2 compatibility - Resolute removed cgroup v1
mkdir -p /home/kasm-user/.config/docker
cat > /home/kasm-user/.config/docker/daemon.json << 'EOF'
{
  "storage-driver": "fuse-overlayfs",
  "exec-opts": ["native.cgroupdriver=cgroupfs"]
}
EOF
chown -R 1000:0 /home/kasm-user/.config/docker

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