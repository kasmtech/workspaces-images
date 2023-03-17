#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "OBS for arm64 currently not supported, skipping install"
    exit 0
fi


if grep -q "ID=debian" /etc/os-release; then
  apt-get update
  apt-get install -y obs-studio
else
  apt-get update
  apt-get install -y mesa-utils libglu1-mesa-dev freeglut3-dev mesa-common-dev
  add-apt-repository -y ppa:obsproject/obs-studio
  apt-get update
  apt-get install -y obs-studio
fi

cp /usr/share/applications/com.obsproject.Studio.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/com.obsproject.Studio.desktop

wget https://github.com/CatxFish/obs-v4l2sink/releases/download/0.1.0/obs-v4l2sink.deb
apt-get install ./obs-v4l2sink.deb
rm -f obs-v4l2sink.deb
