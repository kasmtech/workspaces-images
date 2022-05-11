#!/usr/bin/env bash
set -ex

apt-get update
apt-get install -y software-properties-common

add-apt-repository -y ppa:inkscape.dev/stable
apt-get update
apt-get install -y inkscape

# Default settings and desktop icon
cp /usr/share/applications/org.inkscape.Inkscape.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/org.inkscape.Inkscape.desktop
