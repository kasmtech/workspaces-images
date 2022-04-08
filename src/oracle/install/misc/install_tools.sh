#!/usr/bin/env bash
set -ex

if [ -f /usr/bin/dnf ]; then
  dnf install -y nano zip wget xdotool
  dnf clean all
else
  yum install -y nano zip wget xdotool
  yum clean all
fi
