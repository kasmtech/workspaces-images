#!/usr/bin/env bash
set -ex
if [ "${DISTRO}" == "oracle8" ]; then
  dnf install -y gimp
  dnf clean all
else
  yum install -y gimp
  yum clean all
fi
cp /usr/share/applications/gimp.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/gimp.desktop
