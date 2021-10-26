#!/usr/bin/env bash
set -ex
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/x64/g')

wget -q https://update.code.visualstudio.com/latest/linux-deb-${ARCH}/stable -O vs_code.deb
dpkg -i vs_code.deb
sed -i 's#/usr/share/code/code#/usr/share/code/code --no-sandbox##' /usr/share/applications/code.desktop
cp /usr/share/applications/code.desktop $HOME/Desktop
chmod +x $HOME/Desktop/code.desktop
chown 1000:1000 $HOME/Desktop/code.desktop
rm vs_code.deb

# Conveniences for python development
apt-get update
apt-get install -y python3-setuptools \
                   python3-venv \
                   python3-virtualenv \
                   maximus
