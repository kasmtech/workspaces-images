#!/usr/bin/env bash
zypper install -yn gimp
zypper clean --all
cp /usr/share/applications/gimp.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/gimp.desktop
