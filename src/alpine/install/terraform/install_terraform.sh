#!/usr/bin/env bash
set -ex

if grep -q v3.23 /etc/os-release || grep -q v3.22 /etc/os-release || grep -q v3.21 /etc/os-release; then
  apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    opentofu
fi
