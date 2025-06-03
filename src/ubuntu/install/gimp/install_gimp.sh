# #!/usr/bin/env bash
# set -ex

# # Install GIMP
# apt-get update
# apt-get install -y gimp
# cp /usr/share/applications/gimp.desktop $HOME/Desktop/
# chmod +x $HOME/Desktop/gimp.desktop

# # Cleanup for app layer
# chown -R 1000:0 $HOME
# find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
# if [ -z ${SKIP_CLEAN+x} ]; then
#   apt-get autoclean
#   rm -rf \
#     /var/lib/apt/lists/* \
#     /var/tmp/* \
#     /tmp/*
# fi



#!/usr/bin/env bash
set -ex
ARCH=$(uname -m | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
mkdir -p /opt/gimp-3
cd /opt/gimp-3


if [ "${ARCH}" == "amd64" ]; then
  wget -q https://download.gimp.org/gimp/v3.0/linux/GIMP-3.0.4-x86_64.AppImage -O gimp.AppImage
else
  wget -q https://download.gimp.org/gimp/v3.0/linux/GIMP-3.0.4-aarch64.AppImage -O gimp.AppImage
fi

chmod +x gimp.AppImage
./gimp.AppImage --appimage-extract
rm gimp.AppImage
chown  -R 1000:1000 /opt/gimp-3

cat >/opt/gimp-3/squashfs-root/launcher <<EOL
#!/usr/bin/env bash
export APPDIR=/opt/gimp-3/squashfs-root/
/opt/gimp-3/squashfs-root/AppRun
EOL

chmod +x /opt/gimp-3/squashfs-root/launcher

sed -i 's@^Exec=.*@Exec=/opt/gimp-3/squashfs-root/launcher@g' /opt/gimp-3/squashfs-root/*gimp*.desktop
sed -i 's@^Icon=.*@Icon=/opt/gimp-3/squashfs-root/org.gimp.GIMP.Stable.svg@g' /opt/gimp-3/squashfs-root/*gimp*.desktop
cp /opt/gimp-3/squashfs-root/*gimp*.desktop  $HOME/Desktop/gimp.desktop
cp /opt/gimp-3/squashfs-root/*gimp*.desktop /usr/share/applications/gimp.desktop
chmod +x $HOME/Desktop/gimp.desktop
chmod +x /usr/share/applications/gimp.desktop

