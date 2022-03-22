#!/usr/bin/env bash
set -ex
apt-get update
if [[ "$(lsb_release -cs)" == "bionic" ]];
then
    apt-get install -y maximus
fi
apt-get install -y gimp
cp /usr/share/applications/gimp.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/gimp.desktop