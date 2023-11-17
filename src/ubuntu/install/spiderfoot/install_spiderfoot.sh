#!/usr/bin/env bash
set -xe
echo "Install Spiderfoot"

apt-get update
apt-get install -y python3-pip

SPIDERFOOT_HOME=$HOME/spiderfoot

mkdir -p $SPIDERFOOT_HOME
cd $SPIDERFOOT_HOME
wget https://github.com/smicallef/spiderfoot/archive/v4.0.tar.gz
tar zxvf v4.0.tar.gz
cd spiderfoot-4.0
pip3 install -r requirements.txt

chown -R 1000:1000 $SPIDERFOOT_HOME