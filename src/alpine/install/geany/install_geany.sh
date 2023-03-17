#!/usr/bin/env bash
set -ex

apk add --no-cache \
  geany

# Desktop icon
cp /usr/share/applications/geany.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/geany.desktop
