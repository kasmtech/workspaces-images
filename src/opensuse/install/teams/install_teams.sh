#!/usr/bin/env bash
set -ex
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Teams for arm64 currently not supported, skipping install"
    exit 0
fi


curl -L -o teams.rpm "https://go.microsoft.com/fwlink/p/?LinkID=2112907&clcid=0x409&culture=en-us&country=US"
rpm -i teams.rpm
rm teams.rpm
sed -i "s/Exec=teams/Exec=teams --no-sandbox/g" /usr/share/applications/teams.desktop
cp /usr/share/applications/teams.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/teams.desktop
