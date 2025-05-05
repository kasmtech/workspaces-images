#!/usr/bin/env bash
set -ex
mkdir -p /opt/zoho-mail-desktop
cd /opt/zoho-mail-desktop
wget -q https://downloads.zohocdn.com/zmail-desktop/linux/zoho-mail-desktop-x64-v1.3.2.AppImage -O zoho-mail-desktop.AppImage
chmod +x zoho-mail-desktop.AppImage
./zoho-mail-desktop.AppImage --appimage-extract
rm zoho-mail-desktop.AppImage
chown  -R 1000:1000 /opt/zoho-mail-desktop

cat >/opt/zoho-mail-desktop/squashfs-root/launcher <<EOL
#!/usr/bin/env bash
export APPDIR=/opt/zoho-mail-desktop/squashfs-root/
/opt/zoho-mail-desktop/squashfs-root/AppRun --no-sandbox "$@"
EOL

chmod +x /opt/zoho-mail-desktop/squashfs-root/launcher

sed -i 's@^Exec=.*@Exec=/opt/zoho-mail-desktop/squashfs-root/launcher@g' /opt/zoho-mail-desktop/squashfs-root/zoho-mail-desktop.desktop
sed -i 's@^Icon=.*@Icon=/opt/zoho-mail-desktop/squashfs-root/zoho-mail-desktop.png@g' /opt/zoho-mail-desktop/squashfs-root/zoho-mail-desktop.desktop
cp /opt/zoho-mail-desktop/squashfs-root/zoho-mail-desktop.desktop  $HOME/Desktop
cp /opt/zoho-mail-desktop/squashfs-root/zoho-mail-desktop.desktop /usr/share/applications/
chmod +x $HOME/Desktop/zoho-mail-desktop.desktop
chmod +x /usr/share/applications/zoho-mail-desktop.desktop

# Set default mail client
# These steps work but it would be better to find a built in command that can be used to set this up
mkdir -p  $HOME/.config/
cat >>$HOME/.config/mimeapps.list <<EOL
[Added Associations]
x-scheme-handler/mailto=exo-mail-reader.desktop
EOL

mkdir -p $HOME/.config/xfce4/
cat >>$HOME/.config/xfce4/helpers.rc <<EOL
MailReader=custom-MailReader
EOL

mkdir -p $HOME/.local/share/xfce4/helpers/
cat >>$HOME/.local/share/xfce4/helpers/custom-MailReader.desktop <<EOL
[Desktop Entry]
NoDisplay=true
Version=1.0
Encoding=UTF-8
Type=X-XFCE-Helper
X-XFCE-Category=MailReader
X-XFCE-CommandsWithParameter=/opt/zoho-mail-desktop/squashfs-root/launcher "%s"
Icon=launcher
Name=launcher
X-XFCE-Commands=/opt/zoho-mail-desktop/squashfs-root/launcher
EOL


#chown 1000:1000 $HOME/Desktop/code.desktop


