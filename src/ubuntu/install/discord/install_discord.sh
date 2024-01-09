#!/usr/bin/env bash
set -ex

# Install Discord from deb
apt-get update
curl -L -o discord.deb  "https://discord.com/api/download?platform=linux&format=deb"
apt-get install -y ./discord.deb
rm discord.deb

# Default config values
mkdir -p $HOME/.config/discord/
echo '{"SKIP_HOST_UPDATE": true}' > $HOME/.config/discord/settings.json

# Desktop file setup
sed -i "s@Exec=/usr/share/discord/Discord@Exec=/usr/share/discord/Discord --no-sandbox@g"  /usr/share/applications/discord.desktop
cp /usr/share/applications/discord.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/discord.desktop

# Cleanup
if [ -z ${SKIP_CLEAN+x} ]; then
    apt-get autoclean
    rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*
fi

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
