#!/usr/bin/env bash
set -ex

# Install Retroarch
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
add-apt-repository -y ppa:libretro/stable
apt-get update
apt-get install -y retroarch unzip

# Deskto icon
cp /usr/share/applications/retroarch.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/retroarch.desktop

# Assets install
mkdir -p $HOME/.config/retroarch/{assets,cores}
cp $SCRIPT_PATH/retroarch.cfg $HOME/.config/retroarch/retroarch.cfg
echo "Downloading Assets"
wget -q https://buildbot.libretro.com/assets/frontend/assets.zip
wget -q https://buildbot.libretro.com/assets/frontend/info.zip
unzip assets.zip -d $HOME/.config/retroarch/assets
unzip info.zip -d $HOME/.config/retroarch/cores
rm -f assets.zip info.zip
chown -R 1000:1000 $HOME/.config/retroarch

# Wrap with VGL
rm /usr/bin/retroarch
cat >/usr/bin/retroarch <<EOL
#!/usr/bin/env bash
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Retroarch with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /usr/games/retroarch "\$@"
else
    echo "Starting Retroarch"
    /usr/games/retroarch "\$@"
fi
EOL
chmod +x /usr/bin/retroarch

cat >/usr/bin/desktop_ready <<EOL
#!/usr/bin/env bash
until pids=\$(pidof Thunar); do sleep .5; done
EOL
chmod +x /usr/bin/desktop_ready

# Cleanup
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
