#!/usr/bin/env bash
set -ex

# Install Pinta
apt-get update
apt-get install -y pinta

# Default settings and desktop icon
cp /usr/share/applications/pinta.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/pinta.desktop

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
