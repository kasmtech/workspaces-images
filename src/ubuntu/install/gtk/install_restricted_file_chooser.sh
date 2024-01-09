#!/bin/bash

set -e

# Just remove xdg-open for Jammy
if [ "$(lsb_release -cs)" == "jammy" ]; then
  rm -f /usr/bin/xdg-open
  exit 0
fi

libgtk_deb=libgtk.deb
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

wget https://kasmweb-build-artifacts.s3.amazonaws.com/kasm-gtk-3-restricted-file-chooser/5d4c4e0e3729156c5ab8cd5ff01e7be87db1dbff/output/libgtk-3-0_3.22.30-1ubuntu4_${ARCH}.deb -O $libgtk_deb

apt-get install -y --allow-downgrades ./"$libgtk_deb"
rm "$libgtk_deb"
