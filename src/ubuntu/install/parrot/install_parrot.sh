#!/bin/bash
set -ex

# Set proper bashrc
cp /root/.bashrc $HOME/.bashrc
chown 1000:1000 $HOME/.bashrc

# Install parrot tools
apt-get update
apt-get install -y \
  parrot-meta-crypto \
  parrot-meta-devel \
  parrot-tools-infogathering \
  parrot-tools-vuln \
  parrot-tools-web \
  parrot-tools-pwn \
  parrot-tools-maintain \
  parrot-tools-postexploit \
  parrot-tools-password \
  parrot-tools-sniff \
  parrot-tools-forensics \
  parrot-tools-reversing \
  parrot-tools-cloud \
  powershell-empire- \
  codium-

# Disable power manager
rm -f /usr/share/xfce4/panel/plugins/power-manager-plugin.desktop

# Cleanup
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi
