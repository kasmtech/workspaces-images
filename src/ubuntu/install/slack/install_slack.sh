#!/usr/bin/env bash
set -ex
wget -q https://downloads.slack-edge.com/linux_releases/slack-desktop-4.3.2-amd64.deb
apt-get update
apt-get install -y maximus
apt-get install -y ./slack-desktop-4.3.2-amd64.deb
rm slack-desktop-4.3.2-amd64.deb
sed -i 's,/usr/bin/slack,/usr/bin/slack --no-sandbox,g' /usr/share/applications/slack.desktop
cp /usr/share/applications/slack.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/slack.desktop
chown 1000:1000 $HOME/Desktop/slack.desktop
