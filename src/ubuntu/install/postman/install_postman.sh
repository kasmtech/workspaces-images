#!/usr/bin/env bash
set -ex
wget -q https://dl.pstmn.io/download/latest/linux64 -O postman.tar.gz
mkdir -p /opt/
tar -xvzf postman.tar.gz  -C /opt/
rm postman.tar.gz

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
chown 1000:1000 $HOME/Desktop/postman.desktop
