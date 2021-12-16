#!/bin/bash
set -e
set -x

cd /tmp/
git clone https://github.com/tracelabs/tlosint-live.git
cd /tmp/tlosint-live/

#### Setup Desktop Icons, backgrounds, etc ####
rsync -aviu kali-config/common/includes.chroot/etc/ /etc/
rsync -aviu kali-config/common/includes.chroot/usr/ /usr/

mv /etc/skel/Desktop/*.pdf $HOME/Desktop/

#### Install all tracelabs image packages ####
apt-get update
#                                                              rm lines with # | Delete Empty lines | 
cat kali-config/variant-tracelabs/package-lists/kali.list.chroot | sed '/^#/d' | sed '/^$/d' | xargs --no-run-if-empty apt-get install -y

sh kali-config/common/hooks/normal/osint-packages.chroot

useradd kasm-user 
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

pip3 install --force-reinstall zope.event

sed -i 's/sudo //g' /usr/share/applications/tl*.desktop

rm -rf /var/lib/apt/lists/*

rm -rf /tmp/tlosint-live
