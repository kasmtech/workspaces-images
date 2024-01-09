#!/usr/bin/env bash
set -ex

# Install LibreOffice
apt-get update
apt-get install -y software-properties-common
add-apt-repository ppa:libreoffice/ppa
apt-get update
apt-get install -y libreoffice

# Desktop icon
sed -i "s@Exec=libreoffice@Exec=env LD_LIBRARY_PATH=:/usr/lib/libreoffice/program:/usr/lib/$(arch)-linux-gnu/ libreoffice@g" /usr/share/applications/libreoffice-*.desktop
cp /usr/share/applications/libreoffice-startcenter.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/libreoffice-startcenter.desktop
chmod +x $HOME/Desktop/libreoffice-startcenter.desktop

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
