#!/usr/bin/env bash
set -ex
dpkg --add-architecture i386
apt-get update

apt-get install -y steam-installer
cp /usr/share/applications/steam.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/steam.desktop
chown 1000:1000 $HOME/Desktop/steam.desktop
