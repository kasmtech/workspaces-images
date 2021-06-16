#!/usr/bin/env bash
set -ex

apt-get update
apt-get install -y software-properties-common
apt-add-repository -y ppa:remmina-ppa-team/remmina-next
apt-get update
apt-get install -y remmina remmina-plugin-rdp remmina-plugin-secret remmina-plugin-spice xdotool
cp /usr/share/applications/org.remmina.Remmina.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/org.remmina.Remmina.desktop
chown 1000:1000 $HOME/Desktop/org.remmina.Remmina.desktop