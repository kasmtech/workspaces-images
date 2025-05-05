#!/usr/bin/env bash
set -xe

SPIDERFOOT_VERSION=$(curl -sX GET "https://api.github.com/repos/smicallef/spiderfoot/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]')

# Install Spiderfoot
echo "Install Spiderfoot"
apt-get update
apt-get install -y python3-pip
SPIDERFOOT_HOME=$HOME/spiderfoot
mkdir -p $SPIDERFOOT_HOME
cd $SPIDERFOOT_HOME
wget https://github.com/smicallef/spiderfoot/archive/${SPIDERFOOT_VERSION}.tar.gz
tar zxvf ${SPIDERFOOT_VERSION}.tar.gz
rm ${SPIDERFOOT_VERSION}.tar.gz
cd spiderfoot-*
pip3 install -r requirements.txt

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

