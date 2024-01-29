#!/usr/bin/env bash
set -ex

# Install Audacity
apt-get update
apt-get install -y audacity
rm -rf \
  /var/lib/apt/lists/* \
  /var/tmp/*

# Default settings and desktop icon
mkdir -p $HOME/.audacity-data/
cp /dockerstartup/install/audacity/audacity.cfg $HOME/.audacity-data/
cp /usr/share/applications/audacity.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/audacity.desktop

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
