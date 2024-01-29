#!/usr/bin/env bash
set -ex

if [ "$(arch)" == "aarch64" ] ; then
    echo "Zoom for arm64 currently not supported, skipping install"
    exit 0
fi


wget -q https://zoom.us/client/latest/zoom_$(arch).rpm
if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
  dnf localinstall -y zoom_$(arch).rpm
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
else
  yum localinstall -y zoom_$(arch).rpm
  if [ -z ${SKIP_CLEAN+x} ]; then
    yum clean all
  fi
fi
rm zoom_$(arch).rpm
sed -i 's,/usr/bin/zoom,/usr/bin/zoom --no-sandbox,g' /usr/share/applications/Zoom.desktop
cp /usr/share/applications/Zoom.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/Zoom.desktop
