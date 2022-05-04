#!/usr/bin/env bash
set -ex

# Install
if [[ "${DISTRO}" == @(centos|oracle7|oracle8) ]]; then
  if [ "${DISTRO}" == "oracle8" ]; then
    dnf install -y thunderbird
    dnf clean all
  else
    yum install -y thunderbird
    yum clean all
  fi
elif [ "${DISTRO}" == "opensuse" ]; then
  zypper install -yn MozillaThunderbird
  zypper clean --all
else
  apt-get update
  apt-get install -y thunderbird
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi

# Desktop icon
cp /usr/share/applications/thunderbird.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/thunderbird.desktop
