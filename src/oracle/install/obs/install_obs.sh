#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "$ARCH" == "arm64" ] ; then
  echo "OBS is not supported on arm64, skipping OBS installation"
  exit 0
fi

if [ "${DISTRO}" == "oracle8" ]; then
  dnf install -y obs-studio
  dnf clean all
else
  yum install -y obs-studio
  yum clean all
fi

cp /usr/share/applications/com.obsproject.Studio.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/com.obsproject.Studio.desktop

