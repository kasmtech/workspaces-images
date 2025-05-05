#!/usr/bin/env bash
set -ex

apk add --no-cache \
  git \
  tmux \
  vlc-qt

# Desktop icon
cp /usr/share/applications/vlc.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/vlc.desktop


