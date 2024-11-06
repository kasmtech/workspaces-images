#!/bin/bash

set -e

# Just remove xdg-open for Jammy and Noble
if [[ "$(lsb_release -cs)" == @(jammy|noble) ]]; then
  rm -f /usr/bin/xdg-open
  exit 0
fi

libgtk_deb=libgtk.deb
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

wget https://kasmweb-build-artifacts.s3.amazonaws.com/kasm-gtk-3-restricted-file-chooser/9d36e33ee66b031cef038448a6a8cce946765473/output/libgtk-3-0_3.24.20-0ubuntu1.2_${ARCH}.deb -O $libgtk_deb

apt-get install -y --allow-downgrades ./"$libgtk_deb"
rm "$libgtk_deb"
