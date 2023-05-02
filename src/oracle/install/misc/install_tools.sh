#!/usr/bin/env bash
set -ex

if [ -f /usr/bin/dnf ]; then
  dnf install -y nano zip wget xdotool
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
else
  yum install -y nano zip wget xdotool
  if [ -z ${SKIP_CLEAN+x} ]; then
    yum clean all
  fi
fi
