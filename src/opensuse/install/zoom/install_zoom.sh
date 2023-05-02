#!/usr/bin/env bash
set -ex

if [ "$(arch)" == "aarch64" ] ; then
    echo "Zoom for arm64 currently not supported, skipping install"
    exit 0
fi


wget -q https://zoom.us/client/latest/zoom_openSUSE_$(arch).rpm
wget -O /tmp/package-signing-key.pub https://zoom.us/linux/download/pubkey
rpm --import /tmp/package-signing-key.pub
rm -f /tmp/package-signing-key.pub
zypper install -yn --allow-unsigned-rpm zoom_openSUSE_$(arch).rpm
if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
rm zoom_openSUSE_$(arch).rpm
sed -i 's,/usr/bin/zoom,/usr/bin/zoom --no-sandbox,g' /usr/share/applications/Zoom.desktop
cp /usr/share/applications/Zoom.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/Zoom.desktop
