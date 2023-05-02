#!/usr/bin/env bash
set -ex

zypper install -yn \
  libreoffice \
  libreoffice-base \
  libreoffice-calc \
  libreoffice-draw \
  libreoffice-impress \
  libreoffice-math \
  libreoffice-writer
if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
cp /usr/share/applications/libreoffice-startcenter.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/libreoffice-startcenter.desktop
chown 1000:1000 $HOME/Desktop/libreoffice-startcenter.desktop
