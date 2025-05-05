#!/usr/bin/env bash
set -ex

apk add --no-cach \
  blender

# Desktop icon
cp /usr/share/applications/blender.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/blender.desktop
