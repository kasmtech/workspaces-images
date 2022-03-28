#!/usr/bin/env bash
set -ex
apt-get update

curl -L -o discord.deb  "https://discord.com/api/download?platform=linux&format=deb"
apt-get install -y ./discord.deb
rm discord.deb
sed -i "s@Exec=/usr/share/discord/Discord@Exec=/usr/share/discord/Discord --no-sandbox@g"  /usr/share/applications/discord.desktop
cp /usr/share/applications/discord.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/discord.desktop