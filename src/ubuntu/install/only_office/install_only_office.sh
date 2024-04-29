#!/usr/bin/env bash
set -ex

# Install Only Office
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "$ARCH" == "arm64" ] ; then
  echo "Only Office is not supported on arm64, skipping Only Office installation"
  exit 0
fi
curl -L -o /tmp/only_office.deb "https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_${ARCH}.deb"
apt-get update
apt-get install -y /tmp/only_office.deb
rm -rf /tmp/only_office.deb

# Desktop icon
cp /usr/share/applications/onlyoffice-desktopeditors.desktop $HOME/Desktop
sed -i 's/ONLYOFFICE Desktop Editors/ONLYOFFICE/g' $HOME/Desktop/onlyoffice-desktopeditors.desktop
chmod +x $HOME/Desktop/onlyoffice-desktopeditors.desktop
# KASM-1541
sed -i 's#/usr/bin/onlyoffice-desktopeditors %U$#bash -c "source ~/.bashrc \&\& /usr/bin/onlyoffice-desktopeditors %U"#' /usr/share/applications/onlyoffice-desktopeditors.desktop

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi
