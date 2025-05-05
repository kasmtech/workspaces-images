#!/usr/bin/env bash
set -ex

zypper install -yn nano zip wget xdotool

if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
