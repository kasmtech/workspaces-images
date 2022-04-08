#!/usr/bin/env bash
set -ex

if [ "${DISTRO}" == "oracle8" ]; then
  dnf install -y ansible
  dnf clean all
else
  yum install -y ansible
  yum clean all
fi
