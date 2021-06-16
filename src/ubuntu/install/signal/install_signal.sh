#!/usr/bin/env bash
set -ex
wget -O- https://updates.signal.org/desktop/apt/keys.asc | apt-key add -
echo "deb [arch=amd64] https://updates.signal.org/desktop/apt xenial main" |  tee -a /etc/apt/sources.list.d/signal-xenial.list
apt-get update
apt-get install -y signal-desktop maximus
cp /usr/share/applications/signal-desktop.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/signal-desktop.desktop
