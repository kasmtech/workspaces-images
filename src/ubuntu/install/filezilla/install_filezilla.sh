#!/usr/bin/env bash
set -ex

# Install Filezilla
apt-get update
apt-get install -y filezilla
rm -rf \
  /var/lib/apt/lists/* \
  /var/tmp/*

# Default settings and desktop icon
mkdir -p $HOME/.config/filezilla
cp /dockerstartup/install/filezilla/filezilla.xml $HOME/.config/filezilla
cp /usr/share/applications/filezilla.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/filezilla.desktop

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
