#!/usr/bin/env bash
set -ex

# Install the PPAPI and NPAPI flash plugins via adobe-flashplugin
# Update firefox to use the PPAPI plugin as it includes more features not available in the NPAPI versoin
# https://help.ubuntu.com/18.04/ubuntu-help/net-install-flash.html.en

echo "deb http://archive.canonical.com/ubuntu/ $(lsb_release -cs) partner" > /etc/apt/sources.list.d/canonical_partner.list
apt-get update
apt-get install -y browser-plugin-freshplayer-pepperflash adobe-flashplugin
rm /etc/apt/sources.list.d/canonical_partner.list
