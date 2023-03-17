#!/usr/bin/env bash
set -ex

apk add --no-cache \
  pinta

# Default settings and desktop icon
cp /usr/share/applications/pinta.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/pinta.desktop
