#!/usr/bin/env bash
set -ex
# This script should be executed as a non-root user.
# User verification: deny running as root
if [ "$(id -u)" = "0" ]; then
  >&2 echo "Refusing to install rootless Docker as the root user"; exit 1
fi

echo "Installing Docker"
curl -fsSL https://get.docker.com/rootless | sh

dockerd --version
docker --version

echo "Installing Docker Compose"
mkdir -p "${DOCKER_BIN}"/cli-plugins
COMPOSE_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/compose/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]');
COMPOSE_OS=$(uname -s)
curl -L https://github.com/docker/compose/releases/download/"${COMPOSE_RELEASE}"/docker-compose-"${COMPOSE_OS,,}"-"$(uname -m)" -o "${DOCKER_BIN}"/cli-plugins/docker-compose
chmod +x "${DOCKER_BIN}"/cli-plugins/docker-compose
