#!/usr/bin/env bash
zypper install -yn gimp
if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
cp /usr/share/applications/gimp.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/gimp.desktop
