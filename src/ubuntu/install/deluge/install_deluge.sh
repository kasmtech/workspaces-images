#!/usr/bin/env bash
set -ex

apt-get update
apt-get install -y software-properties-common

add-apt-repository -y ppa:deluge-team/stable
apt-get update
apt-get install -y deluge

# Desktop Icon
cp /usr/share/applications/deluge.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/deluge.desktop
