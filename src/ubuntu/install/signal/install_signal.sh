#!/usr/bin/env bash
set -ex
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Signal for arm64 currently not supported, skipping install"
    exit 0
fi


# Signal only releases its desktop app under the xenial release, however it is compatible with all versions of Debian and Ubuntu that we support.
wget -O- https://updates.signal.org/desktop/apt/keys.asc | apt-key add -
echo "deb [arch=${ARCH}] https://updates.signal.org/desktop/apt xenial main" |  tee -a /etc/apt/sources.list.d/signal-xenial.list
apt-get update

apt-get install -y signal-desktop
cp /usr/share/applications/signal-desktop.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/signal-desktop.desktop
