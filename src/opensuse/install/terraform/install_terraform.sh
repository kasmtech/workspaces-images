#!/usr/bin/env bash
set -ex

zypper install -yn \
  terraform \
  terraform-provider-aws \
  terraform-provider-azurerm \
  terraform-provider-google \
  terraform-provider-kubernetes \
  terraform-provider-openstack
if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
