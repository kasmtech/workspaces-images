#!/usr/bin/env bash
set -ex

# Install vsCode
cd /dockerstartup/install/cursor/
wget -q "https://downloader.cursor.sh/linux/appImage/x64" -O cursor.AppImage
chmod +x cursor.AppImage
./cursor.AppImage --appimage-extract
mv squashfs-root /usr/share/cursor
cp .config/Cursor $HOME/.config/ -a
cp .cursor $HOME/ -a
chown 1000:1000 $HOME/.config/Cursor
chown 1000:1000 $HOME/.cursor

# Desktop icon
mkdir -p /usr/share/icons/hicolor/apps
wget -O /usr/share/icons/hicolor/apps/cursor.png "https://miro.medium.com/v2/resize:fit:256/format:webp/1*YLg8VpqXaTyRHJoStnMuog.png"
sed -i '/Icon=/c\Icon=/usr/share/icons/hicolor/apps/cursor.png' /usr/share/cursor/cursor.desktop
sed -i 's#Exec=#Exec=/usr/share/cursor/#' /usr/share/cursor/cursor.desktop
cp /usr/share/cursor/cursor.desktop $HOME/Desktop
chmod +x  $HOME/Desktop/cursor.desktop
chmod 755 -R /usr/share/cursor
chmod +x  /usr/share/cursor/AppRun
chmod +x  /usr/share/cursor/cursor
chown 1000:1000 $HOME/Desktop/cursor.desktop

rm cursor.AppImage

# Conveniences for python development
apt-get update
apt-get install -y python3-setuptools \
                   python3-venv \
                   python3-virtualenv
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
