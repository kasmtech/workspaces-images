#!/usr/bin/env bash
set -ex

# Install Qbittorrent
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable
apt-get update
apt-get install -y qbittorrent

# Default settings and desktop icon
mkdir -p $HOME/.config/qBittorrent
cp /dockerstartup/install/qbittorrent/qBittorrent.conf $HOME/.config/qBittorrent
cp /usr/share/applications/org.qbittorrent.qBittorrent.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/org.qbittorrent.qBittorrent.desktop

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
