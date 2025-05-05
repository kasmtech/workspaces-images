#!/bin/bash
set -e
set -x

# Install kali tools
apt-get update
apt-get install -y \
  kali-tools-top10 \
  autopsy \
  cutycapt \
  dirbuster \
  faraday \
  fern-wifi-cracker \
  guymager \
  hydra \
  legion \
  ophcrack \
  ophcrack-cli \
  python3-greenlet \
  python3-zope.event \
  sqlitebrowser

cd /tmp/
git clone https://github.com/tracelabs/tlosint-live.git
cd /tmp/tlosint-live/

#### Setup Desktop Icons, backgrounds, etc ####
apt-get update
apt-get install -y rsync
rsync -aviu kali-config/common/includes.chroot/etc/ /etc/
rsync -aviu kali-config/common/includes.chroot/usr/ /usr/

mv /etc/skel/Desktop/*.pdf $HOME/Desktop/

#### Install all tracelabs image packages ####
#                                                              rm lines with # | Delete Empty lines | 
cat kali-config/variant-tracelabs/package-lists/kali.list.chroot | sed '/^#/d' | sed '/^$/d' | sed '/firefox-esr/d' | xargs --no-run-if-empty apt-get install -y
sed -i '/m4ll0k/,+3d' kali-config/common/hooks/normal/osint-packages.chroot
sh kali-config/common/hooks/normal/osint-packages.chroot

chown -R 1000:1000 \
    /usr/share/phoneinfoga \
    /usr/share/Spiderpig \
    /usr/share/DumpsterDiver \
    /usr/share/LittleBrother \
    /usr/share/sn0int \
    /usr/share/buster \
    /usr/share/sherlock \
    /usr/share/reconspider \
    /usr/share/WhatsMyName \
    /usr/share/WikiLeaker \
    /usr/share/OnionSearch \
    /usr/share/toutatis 

apt-get install -y python3-pip

sed -i 's/sudo //g' /usr/share/applications/tl*.desktop

### Remove stuff we install later properly
apt-get purge -y \
  chromium

### Install Pulseaudio once again to remove pipewire
apt-get install -y pulseaudio

### Cleanup
echo "exit 0" > /usr/bin/blueman-applet
rm -f /usr/share/xfce4/panel/plugins/power-manager-plugin.desktop
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi
rm -Rf /root
mkdir -p /root
rm -rf /tmp/tlosint-live
