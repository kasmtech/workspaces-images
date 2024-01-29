#!/usr/bin/env bash
set -ex

# Install Insomnia
wget -q "https://updates.insomnia.rest/downloads/ubuntu/latest?&app=com.insomnia.app&source=website" -O insomnia.deb
apt-get update
apt-get install -y ./insomnia.deb
rm insomnia.deb

# Desktop icon
sed -i "s#Exec=/opt/Insomnia/insomnia#Exec=/opt/Insomnia/insomnia --no-sandbox#g"  /usr/share/applications/insomnia.desktop
cp /usr/share/applications/insomnia.desktop $HOME/Desktop
chmod +x $HOME/Desktop/insomnia.desktop
chown 1000:1000 $HOME/Desktop/insomnia.desktop

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
