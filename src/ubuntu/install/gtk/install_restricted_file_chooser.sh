#!/bin/bash

set -e

wget https://kasmweb-build-artifacts.s3.amazonaws.com/kasm-gtk-3-restricted-file-chooser/de486e8c3c5f3d3c0f898fb9d6e05755897b1970/output/libgtk-3-0_3.22.30-1ubuntu4_amd64.deb -O libgtk.deb
apt-get install -y --allow-downgrades ./libgtk.deb
