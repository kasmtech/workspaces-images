#!/usr/bin/env bash
set -ex

# Install Pinta
# For Jammy, build pinta from source because standard package is buggy
if grep -q Jammy /etc/os-release;  then
  # install requirements for building pinta from source
  apt update -y
  apt-get install -y dotnet-sdk-8.0
  apt-get install -y libgtk-3-dev
  apt install -y autotools-dev autoconf-archive gettext intltool libadwaita-1-dev
  # download and install pinta 2.1.2 source
  wget -q https://github.com/PintaProject/Pinta/releases/download/2.1.2/pinta-2.1.2.tar.gz -O /tmp/pinta-2.1.2.tar.gz
  tar -xvzf /tmp/pinta-2.1.2.tar.gz -C /tmp/
  cd /tmp/pinta-2.1.2
  ./configure --prefix=/usr/local
  make install

  # cleanup to reduce image size
  rm -rf /tmp/pinta-2.1.2.tar.gz /tmp/pinta-2.1.2
  apt remove -y libgtk-3-dev autotools-dev autoconf-archive gettext intltool libadwaita-1-dev
  apt autoremove -y

  # create desktop file
  cat >/usr/share/applications/pinta.desktop <<EOL
[Desktop Entry]
Name=Pinta
Comment=Simple Drawing/Editing Program
Exec=/usr/local/bin/pinta
Icon=/usr/local/share/icons/hicolor/96x96/apps/pinta.png
Terminal=false
Type=Application
Categories=Graphics;2DGraphics;RasterGraphics;
EOL
  chmod +x /usr/share/applications/pinta.desktop
  cp /usr/share/applications/pinta.desktop $HOME/Desktop/

else
  apt-get update
  apt-get install -y pinta

  # Default settings and desktop icon
  cp /usr/share/applications/pinta.desktop $HOME/Desktop/
  chmod +x $HOME/Desktop/pinta.desktop
fi

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
