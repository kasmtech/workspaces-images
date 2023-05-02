#!/usr/bin/env bash
set -ex

zypper install -yn ansible
if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
