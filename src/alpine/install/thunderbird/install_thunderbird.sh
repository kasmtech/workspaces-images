#!/usr/bin/env bash
set -ex

apk add --no-cache \
  thunderbird

# Desktop icon
cp /usr/share/applications/thunderbird.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/thunderbird.desktop
