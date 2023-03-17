#!/bin/bash
set -ex

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
  king-phisher \
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
rm -rf \
  /var/lib/apt/lists/* \
  /var/tmp/* \
  /tmp/*

