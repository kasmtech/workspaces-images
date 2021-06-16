#!/usr/bin/env bash
set -xe
echo "Install TorBrowser"

apt-get install -y xz-utils curl
TOR_URL=$(curl -q https://www.torproject.org/download/ | grep downloadLink | grep linux64 | sed 's/.*href="//g'  | cut -d '"' -f1 | head -1)
wget --quiet https://www.torproject.org/${TOR_URL} -O /tmp/torbrowser.tar.xz
tar -xJf /tmp/torbrowser.tar.xz -C /tmp/

# Patch up the Tor Launcher file so we can move the icon to the deskop but not the folder
cp /tmp/tor-browser_en-US/start-tor-browser.desktop /tmp/tor-browser_en-US/start-tor-browser.desktop.bak
sed -i 's/^Name=.*/Name=Tor Browser/g' /tmp/tor-browser_en-US/start-tor-browser.desktop
sed -i 's/Icon=.*/Icon=\/tmp\/tor-browser_en-US\/Browser\/browser\/chrome\/icons\/default\/default128.png/g' /tmp/tor-browser_en-US/start-tor-browser.desktop
sed -i 's/Exec=.*/Exec=sh -c \x27"\/tmp\/tor-browser_en-US\/Browser\/start-tor-browser" --detach || ([ !  -x "\/tmp\/tor-browser_en-US\/Browser\/start-tor-browser" ] \&\& "$(dirname "$*")"\/Browser\/start-tor-browser --detach)\x27 dummy %k/g'  /tmp/tor-browser_en-US/start-tor-browser.desktop


cat >>/tmp/tor-browser_en-US/Browser/TorBrowser/Data/Browser/profile.default/prefs.js <<EOL
user_pref("extensions.torlauncher.prompt_at_startup", false);
user_pref("browser.download.lastDir", "/home/kasm-user/Downloads");
EOL

chown -R 1000:0 /tmp/tor-browser_en-US/


cp /tmp/tor-browser_en-US/start-tor-browser.desktop $HOME/Desktop/
chown 1000:0  $HOME/Desktop/start-tor-browser.desktop

rm /tmp/torbrowser.tar.xz
