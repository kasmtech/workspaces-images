#!/usr/bin/env bash
set -ex

# Install GIMP
apt-get update
apt-get install -y gimp
cp /usr/share/applications/gimp.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/gimp.desktop

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
