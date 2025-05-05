#!/usr/bin/env bash
set -ex

apk add --no-cache \
  inkscape

# Default settings and desktop icon
cp /usr/share/applications/org.inkscape.Inkscape.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/org.inkscape.Inkscape.desktop
