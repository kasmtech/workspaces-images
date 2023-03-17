#!/usr/bin/env bash
set -ex

apk add --no-cache \
  remmina

# Desktop icon
cp /usr/share/applications/org.remmina.Remmina.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/org.remmina.Remmina.desktop
