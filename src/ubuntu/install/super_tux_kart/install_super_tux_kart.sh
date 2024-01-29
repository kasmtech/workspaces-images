#!/usr/bin/env bash
set -ex

# 
VERSION="1.3"
ARCH=$(uname -m | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
build=64bit
if [ "${ARCH}" == "arm64" ] ; then
    build=arm64
fi

# Install binary version from github
mkdir -p /opt/super_tux_kart
cd /tmp/
wget -q https://github.com/supertuxkart/stk-code/releases/download/${VERSION}/SuperTuxKart-${VERSION}-linux-${build}.tar.xz
tar -xf SuperTuxKart* -C /opt/super_tux_kart/
sed -i "s@Exec=supertuxkart@Exec=/opt/super_tux_kart/SuperTuxKart-${VERSION}-linux-${build}/run_game.sh@g" /opt/super_tux_kart/SuperTuxKart-${VERSION}-linux-${build}/data/supertuxkart.desktop
sed -i "s@Icon=supertuxkart@Icon=/opt/super_tux_kart/SuperTuxKart-${VERSION}-linux-${build}/data/supertuxkart.icns@g" /opt/super_tux_kart/SuperTuxKart-${VERSION}-linux-${build}/data/supertuxkart.desktop
cp /opt/super_tux_kart/SuperTuxKart-${VERSION}-linux-${build}/data/supertuxkart.desktop /usr/share/applications/
chmod +x /usr/share/applications/supertuxkart.desktop
cp /opt/super_tux_kart/SuperTuxKart-${VERSION}-linux-${build}/data/supertuxkart.desktop $HOME/Desktop
chmod +x $HOME/Desktop/supertuxkart.desktop
chown 1000:1000 $HOME/Desktop/supertuxkart.desktop

# Modify startup script for VGL
cat >/opt/super_tux_kart/SuperTuxKart-${VERSION}-linux-${build}/run_game.sh <<EOL
#!/bin/bash

export DIRNAME="\$(dirname "\$(readlink -f "\$0")")"
export SYSTEM_LD_LIBRARY_PATH="\$LD_LIBRARY_PATH"

export SUPERTUXKART_DATADIR="\$DIRNAME"
export SUPERTUXKART_ASSETS_DIR="\$DIRNAME/data/"

cd "\$DIRNAME"

export LD_LIBRARY_PATH="\$DIRNAME/lib:\$LD_LIBRARY_PATH"

if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Super Tux Kart with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" "\$DIRNAME/bin/supertuxkart" "\$@"
else
    echo "Starting Super Tux Kart"
    "\$DIRNAME/bin/supertuxkart" "\$@"
fi
EOL

# Longer startup wait
cat >/usr/bin/desktop_ready <<EOL
#!/usr/bin/env bash
until pids=\$(pidof Thunar); do sleep .5; done
EOL
chmod +x /usr/bin/desktop_ready

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
