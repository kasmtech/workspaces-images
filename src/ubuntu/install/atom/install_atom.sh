#!/usr/bin/env bash
set -ex

wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | apt-key add -
echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" \
  > /etc/apt/sources.list.d/atom.list
apt-get update
apt-get install -y atom

# Desktop Icon
cp /usr/share/applications/atom.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/atom.desktop
