#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "$ARCH" == "amd64" ] ; then
  echo "We only install LibreOffice on aarch64, skipping installation"
  exit 0
fi

if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
  dnf install -y \
    libreoffice-core \
    libreoffice-writer \
    libreoffice-impress \
    libreoffice-calc \
    libreoffice-base
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
else
  yum install -y \
    libreoffice-core \
    libreoffice-writer \
    libreoffice-impress \
    libreoffice-calc \
    libreoffice-base
  if [ -z ${SKIP_CLEAN+x} ]; then
    yum clean all
  fi
fi
cp /usr/share/applications/libreoffice-startcenter.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/libreoffice-startcenter.desktop
chown 1000:1000 $HOME/Desktop/libreoffice-startcenter.desktop
