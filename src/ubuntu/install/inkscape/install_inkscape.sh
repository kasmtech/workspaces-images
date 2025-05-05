#!/usr/bin/env bash
set -ex

# Install Inkscape
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:inkscape.dev/stable
apt-get update
apt-get install -y inkscape

# Default settings and desktop icon
cp /usr/share/applications/org.inkscape.Inkscape.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/org.inkscape.Inkscape.desktop

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
