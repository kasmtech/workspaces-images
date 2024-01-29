#!/usr/bin/env bash
set -ex

if grep -q v3.19 /etc/os-release; then
  apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    opentofu
else
  apk add --no-cache \
    terraform
fi
