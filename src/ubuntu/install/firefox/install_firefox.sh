#!/usr/bin/env bash
set -xe

set_centos_desktop_icon() {
  sed -i -e 's!Icon=.\+!Icon=/usr/share/icons/hicolor/48x48/apps/firefox.png!' "$HOME/Desktop/firefox.desktop"
}

echo "Install Firefox"
if [ "$DISTRO" = centos ]; then
  yum install -y firefox p11-kit
else
  apt-mark unhold firefox
  apt-get remove firefox
  apt-get update
  apt-get install -y firefox p11-kit-modules
fi

if [ "$DISTRO" = centos ]; then
  yum clean all
else
  # Plugin to support running flash videos for sites like vimeo
  apt-get install -y browser-plugin-freshplayer-pepperflash
  apt-mark hold firefox
  apt-get clean -y
fi

if [ "$DISTRO" != centos ]; then
  # Update firefox to utilize the system certificate store instead of the one that ships with firefox
  rm /usr/lib/firefox/libnssckbi.so
  ln /usr/lib/$(arch)-linux-gnu/pkcs11/p11-kit-trust.so /usr/lib/firefox/libnssckbi.so
fi

if [ "$DISTRO" = centos ]; then
  preferences_file=/usr/lib64/firefox/browser/defaults/preferences/all-redhat.js
  sed -i -e '/homepage/d' "$preferences_file"
else
  preferences_file=/usr/lib/firefox/browser/defaults/preferences/firefox.js
fi
# Disabling default first run URL
echo "pref(\"datareporting.policy.firstRunURL\", \"\");" >> "$preferences_file"

# Creating Default Profile
firefox -headless -CreateProfile "kasm $HOME/.mozilla/firefox/kasm"

if [ "$DISTRO" = centos ]; then
  set_centos_desktop_icon
fi

# Starting with version 67, Firefox creates a unique profile mapping per installation which is hash generated
#   based off the installation path. Because that path will be static for our deployments we can assume the hash
#   and thus assign our profile to the default for the installation

cat >>$HOME/.mozilla/firefox/profiles.ini <<EOL
[Install4F96D1932A9F858E]
Default=kasm
Locked=1
EOL

chown -R 1000:1000 $HOME/.mozilla
