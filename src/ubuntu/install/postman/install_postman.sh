#!/usr/bin/env bash
set -ex

# Install Postman
wget -q https://dl.pstmn.io/download/latest/linux64 -O postman.tar.gz
mkdir -p /opt/
tar -xvzf postman.tar.gz  -C /opt/
rm postman.tar.gz

# Desktop icon
cat >/usr/share/applications/postman.desktop <<EOL
[Desktop Entry]
Type=Application
Name=Postman
Icon=/opt/Postman/app/resources/app/assets/icon.png
Exec="/opt/Postman/Postman"
Comment=Postman GUI
Categories=Development;Code;
EOL
chmod +x /usr/share/applications/postman.desktop
cp /usr/share/applications/postman.desktop $HOME/Desktop/postman.desktop
chmod +x $HOME/Desktop/postman.desktop

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi
