#!/usr/bin/env bash
set -ex
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
