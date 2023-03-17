#!/bin/bash
set -ex

# Install remnux tools
export HOME=/root
salt-call -l info --local state.sls remnux.addon pillar='{"remnux_user": "remnux"}'
sed -i 's#^Exec=java.*#Exec=java -jar --add-opens=java\.base/java\.lang=ALL-UNNAMED --add-opens=java\.desktop/javax\.swing=ALL-UNNAMED /opt/burpsuite-community/burpsuite-community\.jar#g' /usr/share/applications/burpsuite.desktop

# Remove stuff we install later properly
apt-get purge -y \
  firefox

# Cleanup
rm -f /usr/share/xfce4/panel/plugins/power-manager-plugin.desktop
rm -rf \
  /root \
  /var/lib/apt/lists/* \
  /var/tmp/* \
  /tmp/*
mkdir /root
export HOME=/home/kasm-default-profile
