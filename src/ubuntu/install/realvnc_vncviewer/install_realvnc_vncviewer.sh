#!/usr/bin/env bash
set -ex
VNC_URL=$(curl -q https://www.realvnc.com/en/connect/download/viewer/linux/ | grep "DEB x64" | cut -d '"' -f6 | head -1)

wget -q $VNC_URL -O vnc.deb
apt-get update
apt-get install -y ./vnc.deb
rm vnc.deb

cp /usr/share/applications/realvnc-vncviewer.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/realvnc-vncviewer.desktop
chown 1000:1000 /usr/share/applications/realvnc-vncviewer.desktop

