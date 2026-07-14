#!/usr/bin/env bash
set -ex

zypper addrepo -f "https://download.opensuse.org/repositories/systemsmanagement:terraform/\$releasever/" terraform_repo

zypper --gpg-auto-import-keys refresh

zypper install -yn \
  terraform \
  terraform-provider-aws \
  terraform-provider-azurerm \
  terraform-provider-google \
  terraform-provider-kubernetes
if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
