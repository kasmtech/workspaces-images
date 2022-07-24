#!/usr/bin/env bash

# Adapted from https://docs.unity3d.com/hub/manual/InstallHub.html#install-hub-linux
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
set -ex
sh -c 'echo "deb https://hub.unity3d.com/linux/repos/deb stable main" > /etc/apt/sources.list.d/unityhub.list'
wget -qO - https://hub.unity3d.com/linux/keys/public |  apt-key add -
apt-get update
apt-get install -y unityhub

sed -i 's,/opt/unityhub/unityhub,/opt/unityhub/unityhub --no-sandbox,g' /usr/share/applications/unityhub.desktop


cp /usr/share/applications/unityhub.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/unityhub.desktop
chown 1000:1000 $HOME/Desktop/unityhub.desktop


# Example for pre-installing a unity Editor
#mkdir -p $HOME/Unity/Hub/Editor/2021.3.6f1
#cd /tmp/
#wget -q https://download.unity3d.com/download_unity/7da38d85baf6/UnitySetup-2021.3.6f1 -O UnitySetup
#chmod +x ./UnitySetup
#yes | ./UnitySetup -u -l $HOME/Unity/Hub/Editor/2021.3.6f1
#rm /tmp/UnitySetup
#chown -R 1000:1000 $HOME/Unity