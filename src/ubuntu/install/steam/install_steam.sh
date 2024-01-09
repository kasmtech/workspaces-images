#!/usr/bin/env bash
set -ex

# Install Steam
dpkg --add-architecture i386
apt-get update
apt-get install -y steam-installer

# Desktop icon
cp /usr/share/applications/steam.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/steam.desktop

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
