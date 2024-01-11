#!/usr/bin/env bash
set -ex
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/x64/g')

wget -q https://update.code.visualstudio.com/latest/linux-rpm-${ARCH}/stable -O vs_code.rpm
if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
  wget -q https://update.code.visualstudio.com/latest/linux-rpm-${ARCH}/stable -O vs_code.rpm
  dnf localinstall -y vs_code.rpm
else
  wget -q https://packages.microsoft.com/yumrepos/vscode/code-1.85.1-1702462241.el7.x86_64.rpm  -O vs_code.rpm
  yum localinstall -y vs_code.rpm
fi
mkdir -p /usr/share/icons/hicolor/apps
wget -O /usr/share/icons/hicolor/apps/vscode.svg https://kasm-static-content.s3.amazonaws.com/icons/vscode.svg
sed -i '/Icon=/c\Icon=/usr/share/icons/hicolor/apps/vscode.svg' /usr/share/applications/code.desktop
sed -i 's#/usr/share/code/code#/usr/share/code/code --no-sandbox##' /usr/share/applications/code.desktop
cp /usr/share/applications/code.desktop $HOME/Desktop
chmod +x $HOME/Desktop/code.desktop
chown 1000:1000 $HOME/Desktop/code.desktop
rm vs_code.rpm

# Conveniences for python development
if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
  dnf install -y python3-setuptools python3-virtualenv
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
else
  yum install -y python3-setuptools python3-virtualenv
  if [ -z ${SKIP_CLEAN+x} ]; then
    yum clean all
  fi
fi
