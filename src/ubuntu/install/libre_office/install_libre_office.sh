#!/usr/bin/env bash
set -ex

apt-get update
apt-get install -y software-properties-common

add-apt-repository ppa:libreoffice/ppa
apt-get update
apt-get install -y libreoffice

rm -rf \
  /tmp/* \
  /var/lib/apt/lists/* \
  /var/tmp/*

sed -i "s@Exec=libreoffice@Exec=env LD_LIBRARY_PATH=:/usr/lib/libreoffice/program:/usr/lib/$(arch)-linux-gnu/ libreoffice@g" /usr/share/applications/libreoffice-*.desktop
cp /usr/share/applications/libreoffice-startcenter.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/libreoffice-startcenter.desktop
chmod +x $HOME/Desktop/libreoffice-startcenter.desktop

if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi
