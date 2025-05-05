#!/usr/bin/env bash
set -ex

sed -i 's/download.opensuse.org/mirrorcache-us.opensuse.org/g' /etc/zypp/repos.d/*.repo
zypper install -yn vlc git tmux
if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
