#!/usr/bin/env bash
set -ex

# Install vsCode
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/x64/g')
wget -q https://update.code.visualstudio.com/latest/linux-deb-${ARCH}/stable -O vs_code.deb
apt-get update
apt-get install -y ./vs_code.deb

# Desktop icon
mkdir -p /usr/share/icons/hicolor/apps
wget -O /usr/share/icons/hicolor/apps/vscode.svg https://kasm-static-content.s3.amazonaws.com/icons/vscode.svg
# Find the desktop file; newer VS Code releases ship com.microsoft.VSCode.desktop instead of code.desktop
if [ ! -f /usr/share/applications/code.desktop ]; then
  VSCODE_DESKTOP=$(find /usr/share/applications -maxdepth 1 -name "com.microsoft.VSCode.desktop" | head -1)
  if [ -z "${VSCODE_DESKTOP}" ]; then
    VSCODE_DESKTOP=$(find / -name "code.desktop" 2>/dev/null | head -1)
  fi
  if [ -z "${VSCODE_DESKTOP}" ]; then
    echo "ERROR: could not find a VS Code desktop file" >&2
    exit 1
  fi
  cp "${VSCODE_DESKTOP}" /usr/share/applications/code.desktop
fi
sed -i '/Icon=/c\Icon=/usr/share/icons/hicolor/apps/vscode.svg' /usr/share/applications/code.desktop
sed -i 's#/usr/share/code/code#/usr/share/code/code --no-sandbox##' /usr/share/applications/code.desktop
cp /usr/share/applications/code.desktop $HOME/Desktop
chmod +x $HOME/Desktop/code.desktop
chown 1000:1000 $HOME/Desktop/code.desktop
rm vs_code.deb

# Conveniences for python development
apt-get update
apt-get install -y python3-setuptools \
                   python3-venv \
                   python3-virtualenv

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
