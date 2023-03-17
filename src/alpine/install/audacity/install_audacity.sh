#!/usr/bin/env bash
set -ex

apk add --no-cache \
  audacity

# Desktop icon
cp /usr/share/applications/audacity.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/audacity.desktop
