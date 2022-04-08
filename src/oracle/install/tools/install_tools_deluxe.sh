#!/usr/bin/env bash
set -ex

if [ -f /usr/bin/dnf ]; then
  dnf install -y vlc git tmux
  dnf clean all
else
  yum-config-manager --enable ol7_optional_latest
  yum install -y vlc git tmux
  yum clean all
fi

