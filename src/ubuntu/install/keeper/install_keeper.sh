#!/usr/bin/env bash
set -ex
apt-get update
wget https://www.keepersecurity.com/desktop_electron/Linux/repo/deb/keeperpasswordmanager_16.4.4_amd64.deb -O keeper.deb
apt-get install -y ./keeper.deb
rm -rf keeper.deb
sed -i 's@^Exec=.*@Exec=keeperpasswordmanager --no-sandbox %U@g' /usr/share/applications/keeperpasswordmanager.desktop
cp /usr/share/applications/keeperpasswordmanager.desktop $HOME/Desktop/keeperpasswordmanager.desktop
chmod +x $HOME/Desktop/keeperpasswordmanager.desktop