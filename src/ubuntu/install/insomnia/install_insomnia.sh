#!/usr/bin/env bash
set -ex
wget -q "https://updates.insomnia.rest/downloads/ubuntu/latest?&app=com.insomnia.app&source=website" -O insomnia.deb
apt-get update
apt-get install -y ./insomnia.deb

sed -i "s#Exec=/opt/Insomnia/insomnia#Exec=/opt/Insomnia/insomnia --no-sandbox#g"  /usr/share/applications/insomnia.desktop
cp /usr/share/applications/insomnia.desktop $HOME/Desktop
chmod +x $HOME/Desktop/insomnia.desktop
chown 1000:1000 $HOME/Desktop/insomnia.desktop
rm insomnia.deb
