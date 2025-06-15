#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Terraform for arm64 currently not supported, skipping install"
    exit 0
fi

# Install terraform

# Check if it is ubuntu focal
if [ "$(lsb_release -cs)" == "focal" ]; then
  # Install by downloading binary
  LATEST_VERSION=$(curl -s https://releases.hashicorp.com/terraform/ \
  | grep -oP 'terraform/\K[0-9]+\.[0-9]+\.[0-9]+(?=/)' \
  | sort -V | uniq | tail -1)
  cd /tmp
  curl -fsSL "https://releases.hashicorp.com/terraform/${LATEST_VERSION}/terraform_${LATEST_VERSION}_linux_amd64.zip" -o terraform.zip
  unzip -o terraform.zip
  chmod +x terraform
  mv terraform /usr/bin/
  rm terraform.zip
else
  # Install from repository
  curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
  echo \
  "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list
  apt-get update
  apt-get install -y terraform
fi

# Cleanup
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi
