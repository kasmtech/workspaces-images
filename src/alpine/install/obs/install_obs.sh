#!/usr/bin/env bash
set -ex

apk add --no-cache \
  obs-studio

# Desktop icon
cp /usr/share/applications/com.obsproject.Studio.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/com.obsproject.Studio.desktop
