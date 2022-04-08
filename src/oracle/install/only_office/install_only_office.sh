#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "$ARCH" == "arm64" ] ; then
  echo "Only Office is not supported on arm64, skipping Only Office installation"
  exit 0
fi

curl -L -o only_office.rpm "https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors.$(arch).rpm"
if [ "${DISTRO}" == "oracle8" ]; then
  dnf localinstall -y only_office.rpm
  dnf clean all
else
  yum localinstall -y only_office.rpm
  yum clean all
fi
rm -rf only_office.rpm

cp /usr/share/applications/onlyoffice-desktopeditors.desktop $HOME/Desktop
sed -i 's/ONLYOFFICE Desktop Editors/ONLYOFFICE/g' $HOME/Desktop/onlyoffice-desktopeditors.desktop
chmod +x $HOME/Desktop/onlyoffice-desktopeditors.desktop
# KASM-1541
sed -i 's#/usr/bin/onlyoffice-desktopeditors %U$#bash -c "source ~/.bashrc \&\& /usr/bin/onlyoffice-desktopeditors %U"#' /usr/share/applications/onlyoffice-desktopeditors.desktop
