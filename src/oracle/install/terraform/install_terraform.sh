#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Terraform for arm64 currently not supported, skipping install"
    exit 0
fi

if [ "${DISTRO}" == "oracle8" ]; then
  dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
  dnf install -y terraform
  dnf clean all
else
  yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
  yum install -y terraform
  yum clean all
fi
