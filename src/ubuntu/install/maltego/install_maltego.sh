#!/usr/bin/env bash
set -ex

# Install Maltego
apt-get update
apt-get install -y default-jre curl
MALTEGO_URL=$(curl -sq https://downloads.maltego.com/maltego-v4/info.json | grep -e "url.*deb"  | cut -d '"' -f4 | head -1)
wget -q $MALTEGO_URL -O maltego.deb
apt-get install -y ./maltego.deb
rm maltego.deb

# Desktop icon
cp /usr/share/applications/maltego.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/maltego.desktop
chown 1000:1000 /usr/share/applications/maltego.desktop

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
