#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Terraform for arm64 currently not supported, skipping install"
    exit 0
fi

if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8) ]]; then
  dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
  dnf install -y terraform
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
elif [[ "${DISTRO}" == @(fedora37|fedora38|fedora39) ]]; then
  dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
  dnf install -y terraform
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
else
  yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
  yum install -y terraform
  if [ -z ${SKIP_CLEAN+x} ]; then
    yum clean all
  fi
fi
