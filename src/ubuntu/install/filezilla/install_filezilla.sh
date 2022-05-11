#!/usr/bin/env bash
set -ex
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
