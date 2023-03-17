#!/bin/bash
set -e
set -x

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
cat kali-config/variant-tracelabs/package-lists/kali.list.chroot | sed '/^#/d' | sed '/^$/d' | xargs --no-run-if-empty apt-get install -y

sh kali-config/common/hooks/normal/osint-packages.chroot

chown -R 1000:1000 \
    /usr/share/phoneinfoga \
    /usr/share/Spiderpig \
    /usr/share/DumpsterDiver \
    /usr/share/Infoga \
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

pip3 install --break-system-packages --force-reinstall zope.event

sed -i 's/sudo //g' /usr/share/applications/tl*.desktop

### Remove stuff we install later properly
apt-get purge -y \
  firefox-esr \
  chromium
rm -f /usr/share/xfce4/panel/plugins/power-manager-plugin.desktop

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
  hydra-gtk \
  king-phisher \
  legion \
  ophcrack \
  ophcrack-cli \
  sqlitebrowser

### Cleanup
echo "exit 0" > /usr/bin/blueman-applet
rm -f /usr/share/xfce4/panel/plugins/power-manager-plugin.desktop
rm -rf \
  /var/lib/apt/lists/* \
  /var/tmp/* \
  /tmp/*
rm -Rf /root
mkdir -p /root
rm -rf /tmp/tlosint-live
