#!/usr/bin/env bash
set -ex

apk add --no-cache \
  filezilla

# Desktop icon
cp /usr/share/applications/filezilla.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/filezilla.desktop
