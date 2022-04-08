#!/usr/bin/env bash
set -ex

if [ "$(arch)" == "aarch64" ] ; then
    echo "Zoom for arm64 currently not supported, skipping install"
    exit 0
fi


wget -q https://zoom.us/client/latest/zoom_openSUSE_$(arch).rpm
rpm --import https://zoom.us/linux/download/pubkey
zypper install -yn zoom_openSUSE_$(arch).rpm
zypper clean --all
rm zoom_openSUSE_$(arch).rpm
sed -i 's,/usr/bin/zoom,/usr/bin/zoom --no-sandbox,g' /usr/share/applications/Zoom.desktop
cp /usr/share/applications/Zoom.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/Zoom.desktop
