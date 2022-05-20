#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Zoom for arm64 currently not supported, skipping install"
    exit 0
fi


wget -q  https://zoom.us/client/latest/zoom_${ARCH}.deb
apt-get update
apt-get install -y ./zoom_${ARCH}.deb
rm zoom_amd64.deb
sed -i 's#/usr/bin/zoom#/usr/bin/zoom --no-sandbox##' /usr/share/applications/Zoom.desktop
cp /usr/share/applications/Zoom.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/Zoom.desktop
