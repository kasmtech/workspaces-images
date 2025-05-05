#!/usr/bin/env bash
set -ex

# Install zsnes
dpkg --add-architecture i386
apt-get update
apt-get install -y zsnes

# Input tweaks
mkdir $HOME/.zsnes
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPT_PATH="$(realpath $SCRIPT_PATH)"
cp ${SCRIPT_PATH}/zinput.cfg $HOME/.zsnes/zinput.cfg
chown -R 1000:1000 $HOME/.zsnes

# Desktop Icon
cp /usr/share/applications/zsnes.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/zsnes.desktop

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi
