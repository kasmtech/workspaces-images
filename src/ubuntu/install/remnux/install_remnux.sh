#!/bin/bash
set -x


# Install Salt
wget -nv -O - https://repo.saltproject.io/py3/ubuntu/20.04/amd64/latest/salt-archive-keyring.gpg | apt-key add -
echo deb [arch=amd64] https://repo.saltproject.io/py3/ubuntu/20.04/amd64/3004 focal main > /etc/apt/sources.list.d/saltstack.list
apt-get update
apt-get install -y salt-common 
git clone https://github.com/REMnux/salt-states.git /srv/salt

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
  /tmp/*
mkdir /root
export HOME=/home/kasm-default-profile
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi
