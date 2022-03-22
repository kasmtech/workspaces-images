#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Zoom for arm64 currently not supported, skipping install"
    exit 0
fi


wget -q  https://zoom.us/client/latest/zoom_${ARCH}.deb
apt-get update
if [[ "$(lsb_release -cs)" == "bionic" ]];
then
    apt-get install -y maximus
fi
apt-get install -y ./zoom_${ARCH}.deb
rm zoom_amd64.deb
cp /usr/share/applications/Zoom.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/Zoom.desktop
