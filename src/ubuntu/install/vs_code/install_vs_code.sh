#!/usr/bin/env bash
set -ex
wget -q https://update.code.visualstudio.com/latest/linux-deb-x64/stable -O vs_code_amd64.deb
apt-get update
apt-get install -y ./vs_code_amd64.deb
sed -i 's#/usr/share/code/code#/usr/share/code/code --no-sandbox##' /usr/share/applications/code.desktop
cp /usr/share/applications/code.desktop $HOME/Desktop
chmod +x $HOME/Desktop/code.desktop
chown 1000:1000 $HOME/Desktop/code.desktop
rm vs_code_amd64.deb

# Conveniences for python development
apt-get update
apt-get install -y python3-setuptools \
                   python3-venv \
                   python3-virtualenv \
                   maximus

# Cleanup
apt-get autoclean
rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
