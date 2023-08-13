#!/bin/bash
set -e

# Install kali tools
apt-get update
apt-get install -y \
  kali-tools-top10 \
  autopsy \
  cutycapt \
  dirbuster \
  faraday \
  fern-wifi-cracker \
  guymager \
  hydra-gtk \
  legion \
  ophcrack \
  ophcrack-cli \
  sqlitebrowser

# Remove stuff we install later properly
apt-get purge -y \
  firefox-esr \
  chromium
rm -f /usr/share/xfce4/panel/plugins/power-manager-plugin.desktop

# Cleanup
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi
