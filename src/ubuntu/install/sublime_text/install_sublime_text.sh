#!/usr/bin/env bash
set -ex

# Install Sublime Text
apt-get update
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -
apt-get install -y apt-transport-https
echo "deb https://download.sublimetext.com/ apt/stable/" |  tee /etc/apt/sources.list.d/sublime-text.list
apt-get update
apt-get install -y sublime-text

# Desktop icon
cp /usr/share/applications/sublime_text.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/sublime_text.desktop

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi
