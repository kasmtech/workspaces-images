#!/usr/bin/env bash
set -ex

apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    dbus-user-session \
    kmod \
    iptables \
    openssh-client \
    sudo \
    supervisor \
    uidmap \
    wget
rm -rf /var/lib/apt/list/*

mkdir -p /var/log/supervisor
chown -R 1000:1000 /var/log/supervisor

arch="$(uname --m)"; 
case "$arch" in 
    # amd64
    x86_64) dockerArch='x86_64' ;; 
    # arm32v6
    armhf) dockerArch='armel' ;;
    # arm32v7
    armv7) dockerArch='armhf' ;;
    # arm64v8
    aarch64) dockerArch='aarch64' ;;
    *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;
esac;

curl -o docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"

tar --extract \
    --file docker.tgz \
    --strip-components 1 \
    --directory /usr/local/bin/
rm docker.tgz

dockerd --version
docker --version

echo "Installing Docker Compose"
mkdir -p /usr/local/lib/docker/cli-plugins
curl -L https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

useradd -m -d /home/kasm-user -s /bin/bash kasm-user 
echo 'kasm-user:kasm-user' | chpasswd
echo 'kasm-user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

groupadd docker
adduser kasm-user docker
