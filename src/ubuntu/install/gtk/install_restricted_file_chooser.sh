#!/bin/bash

set -e

libgtk_deb=libgtk.deb
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

wget https://kasmweb-build-artifacts.s3.amazonaws.com/kasm-gtk-3-restricted-file-chooser/5ed0c7b5bf4b56562269b3527b3446febc8bd91a/output/libgtk-3-0_3.22.30-1ubuntu4_${ARCH}.deb -O $libgtk_deb
apt-get install -y --allow-downgrades ./"$libgtk_deb"
rm "$libgtk_deb"
