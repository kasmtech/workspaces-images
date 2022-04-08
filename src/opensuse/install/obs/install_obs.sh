#!/usr/bin/env bash
set -ex

if [ "${DISTRO}" == "oracle8" ]; then
  dnf install -y obs-studio
  dnf clean all
else
  yum install -y obs-studio
  yum clean all
fi

cp /usr/share/applications/com.obsproject.Studio.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/com.obsproject.Studio.desktop

