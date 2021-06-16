#!/usr/bin/env bash
set -ex
wget -q  https://zoom.us/client/latest/zoom_amd64.deb
apt-get update
apt-get install -y maximus
apt-get install -y ./zoom_amd64.deb
rm zoom_amd64.deb
cp /usr/share/applications/Zoom.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/Zoom.desktop