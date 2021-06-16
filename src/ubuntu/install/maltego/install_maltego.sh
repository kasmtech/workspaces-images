#!/usr/bin/env bash
set -ex

apt-get update
apt-get install -y default-jre curl

MALTEGO_URL=$(curl -q https://maltego-downloads.s3.us-east-2.amazonaws.com/info.json | grep -e "url.*deb"  | cut -d '"' -f4 | head -1)

wget -q $MALTEGO_URL -O maltego.deb
apt-get install -y ./maltego.deb
rm maltego.deb

cp /usr/share/applications/maltego.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/maltego.desktop
chown 1000:1000 /usr/share/applications/maltego.desktop

