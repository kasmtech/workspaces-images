#!/usr/bin/env bash
set -ex

if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37) ]]; then
  dnf install -y ansible
  dnf clean all
else
  yum install -y ansible
  yum clean all
fi
