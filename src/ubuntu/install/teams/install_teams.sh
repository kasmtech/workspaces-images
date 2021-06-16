#!/usr/bin/env bash
set -ex
curl -L -o teams.deb  "https://go.microsoft.com/fwlink/p/?linkid=2112886&clcid=0x409&culture=en-us&country=us"
apt-get install -y ./teams.deb
rm teams.deb
sed -i "s/Exec=teams/Exec=teams --no-sandbox/g" /usr/share/applications/teams.desktop
cp /usr/share/applications/teams.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/teams.desktop