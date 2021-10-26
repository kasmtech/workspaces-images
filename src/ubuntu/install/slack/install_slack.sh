#!/usr/bin/env bash
set -ex
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Slack for arm64 currently not supported, skipping install"
    exit 0
fi

wget -q https://downloads.slack-edge.com/linux_releases/slack-desktop-4.3.2-${ARCH}.deb
apt-get update
apt-get install -y maximus
apt-get install -y ./slack-desktop-4.3.2-${ARCH}.deb
rm slack-desktop-4.3.2-${ARCH}.deb
sed -i 's,/usr/bin/slack,/usr/bin/slack --no-sandbox,g' /usr/share/applications/slack.desktop
cp /usr/share/applications/slack.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/slack.desktop
chown 1000:1000 $HOME/Desktop/slack.desktop
