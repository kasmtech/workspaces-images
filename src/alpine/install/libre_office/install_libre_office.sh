#!/usr/bin/env bash
set -ex

apk add --no-cache \
  libreoffice \
  openjdk8-jre \
  openjdk8-jre-base

cp /usr/share/applications/libreoffice-startcenter.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/libreoffice-startcenter.desktop
chmod +x $HOME/Desktop/libreoffice-startcenter.desktop
