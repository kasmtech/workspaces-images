#!/usr/bin/env bash
set -ex

if [[ $(arch) == "aarch64" ]] && $(grep -q "15.6" /etc/os-release); then
  # Have to use this specific repo instead of the generic $releasever due to how the 15.6 repo deals with arm instances
  zypper addrepo -f "https://download.opensuse.org/repositories/systemsmanagement:terraform/openSUSE_Tumbleweed/" terraform_repo
else
  zypper addrepo -f "https://download.opensuse.org/repositories/systemsmanagement:terraform/\$releasever/" terraform_repo
fi

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
