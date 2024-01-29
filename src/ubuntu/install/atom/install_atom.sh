#!/usr/bin/env bash
set -ex

# Install Atom
wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | apt-key add -
echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" \
  > /etc/apt/sources.list.d/atom.list
apt-get update
apt-get install -y atom

# Desktop Icon
sed -i 's#/usr/bin/atom#/usr/bin/atom --no-sandbox#g' /usr/share/applications/atom.desktop
cp /usr/share/applications/atom.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/atom.desktop

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

