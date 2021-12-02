#!/usr/bin/env bash
set -ex

wget https://downloadmirror.hunch.ly/currentversion/hunchly.deb -O /tmp/hunchly.deb
apt-get update
apt-get install -y /tmp/hunchly.deb
rm -rf /tmp/hunchly.deb
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

