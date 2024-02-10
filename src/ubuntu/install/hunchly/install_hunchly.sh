#!/usr/bin/env bash
set -ex

# Install Hunchly
#wget https://downloadmirror.hunch.ly/currentversion/hunchly.deb -O /tmp/hunchly.deb
wget https://kasm-static-content.s3.amazonaws.com/hunchly/hunchly-kasm-linux_installer.deb -O /tmp/hunchly.deb
apt-get update
apt-get install -y /tmp/hunchly.deb
rm -rf /tmp/hunchly.deb

# Bin wrapper for seccomp
mv /usr/lib/hunchly/Hunchly /usr/lib/hunchly/Hunchly-orig
cat >/usr/lib/hunchly/Hunchly <<EOL
#!/bin/bash

BIN=/usr/lib/hunchly/Hunchly-orig

# Run normally on privved containers
if grep -q 'Seccomp:\t0' /proc/1/status; then
  \${BIN} \
   "\$@"
else
  \${BIN} \
  --no-sandbox \
   "\$@"
fi
EOL
chmod +x /usr/lib/hunchly/Hunchly

# Desktop icon
cp /usr/share/applications/hunchly-2.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/hunchly-2.desktop
chmod +x $HOME/Desktop/hunchly-2.desktop

# Install the Hunchly Extension
cat >/etc/opt/chrome/policies/managed/hunchly_extension.json <<EOL
{
  "ExtensionSettings": {
    "amfnegileeghgikpggcebehdepknalbf": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx",
      "toolbar_pin" : "force_pinned"
    }
  }
}
EOL

# Install archive tools
apt-get install -y \
  p7zip-full \
  p7zip-rar \
  thunar-archive-plugin \
  xarchiver

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
