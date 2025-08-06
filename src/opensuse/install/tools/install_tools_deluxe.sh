#!/usr/bin/env bash
set -ex

zypper install -yn vlc git tmux
if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
