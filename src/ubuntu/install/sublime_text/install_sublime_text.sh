#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "$ARCH" == "arm64" ] ; then
  echo "Sublimetext not supported on arm64, skipping installation"
  exit 0
fi

apt-get update
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -
apt-get install -y apt-transport-https
echo "deb https://download.sublimetext.com/ apt/stable/" |  tee /etc/apt/sources.list.d/sublime-text.list
apt-get update
apt-get install -y sublime-text maximus
cp /usr/share/applications/sublime_text.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/sublime_text.desktop
chown 1000:1000 $HOME/Desktop/sublime_text.desktop
