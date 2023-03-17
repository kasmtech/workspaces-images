#!/usr/bin/env bash
set -ex

apk add --no-cache \
  gimp

# Desktop icon
cp /usr/share/applications/gimp.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/gimp.desktop
