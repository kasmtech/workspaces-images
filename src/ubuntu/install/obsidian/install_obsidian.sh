#!/usr/bin/env bash
set -ex
wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.4.5/obsidian_1.4.5_amd64.deb" -O obsidian.deb
apt-get update
apt-get install -y ./obsidian.deb
rm  -f obsidian.deb

sed -i "s#Exec=/opt/Obsidian/obsidian#Exec=/opt/Obsidian/obsidian --no-sandbox#g"  /usr/share/applications/obsidian.desktop
cp /usr/share/applications/obsidian.desktop $HOME/Desktop
chmod +x $HOME/Desktop/obsidian.desktop
chown 1000:1000 $HOME/Desktop/obsidian.desktop