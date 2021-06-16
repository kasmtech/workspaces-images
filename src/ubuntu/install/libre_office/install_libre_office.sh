#!/usr/bin/env bash
### every exit != 0 fails the script
set -ex
apt-get update
apt-get install -y software-properties-common

add-apt-repository -y ppa:libreoffice/ppa
apt-get update
apt-get install -y libreoffice
add-apt-repository -r -y ppa:libreoffice/ppa
cp /usr/share/applications/libreoffice-startcenter.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/libreoffice-startcenter.desktop

