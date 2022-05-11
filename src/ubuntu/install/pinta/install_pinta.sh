#!/usr/bin/env bash
set -ex
apt-get update

apt-get install -y pinta
rm -rf \
  /var/lib/apt/lists/* \
  /var/tmp/*

# Default settings and desktop icon
cp /usr/share/applications/pinta.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/pinta.desktop
