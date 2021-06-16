#!/usr/bin/env bash
set -ex
apt-get update
apt-get install -y chocolate-doom doom-wad-shareware prboom-plus freedoom

mkdir -p $HOME/.local/share/chocolate-doom
echo 'force_software_renderer    1' > $HOME/.local/share/chocolate-doom/chocolate-doom.cfg