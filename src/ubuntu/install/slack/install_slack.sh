#!/usr/bin/env bash
set -ex
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Slack for arm64 currently not supported, skipping install"
    exit 0
fi

# This might prove fragile depending on how often slack changes it's website.
version=$(curl -q https://slack.com/downloads/linux | grep page-downloads__hero__meta-text__version | sed 's/.*Version //g' | cut -d "<" -f1 | head -1)
echo Detected slack version $version


if [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39|opensuse) ]]; then

  wget -q https://downloads.slack-edge.com/releases/linux/${version}/prod/x64/slack-${version}-0.1.el8.x86_64.rpm

  if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
    dnf localinstall -y slack-${version}-0.1.el8.x86_64.rpm
    if [ -z ${SKIP_CLEAN+x} ]; then
      dnf clean all
    fi
  elif [[ "${DISTRO}" == "opensuse" ]]; then
    wget https://slack.com/gpg/slack_pubkey_20230710.gpg
    rpm --import slack_pubkey_20230710.gpg
    zypper install -yn slack-${version}-0.1.el8.x86_64.rpm
    if [ -z ${SKIP_CLEAN+x} ]; then
      zypper clean --all
    fi
  else
    yum localinstall -y slack-${version}-0.1.el8.x86_64.rpm
    if [ -z ${SKIP_CLEAN+x} ]; then
      yum clean all
    fi
  fi

  rm slack-${version}-0.1.el8.x86_64.rpm

else
  wget -q https://downloads.slack-edge.com/releases/linux/${version}/prod/x64/slack-desktop-${version}-${ARCH}.deb
  apt-get update
  apt-get install -y ./slack-desktop-${version}-${ARCH}.deb
  rm slack-desktop-${version}-${ARCH}.deb
  if [ -z ${SKIP_CLEAN+x} ]; then
    apt-get autoclean
    rm -rf \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /tmp/*
  fi
fi


sed -i 's,/usr/bin/slack,/usr/bin/slack --no-sandbox,g' /usr/share/applications/slack.desktop
cp /usr/share/applications/slack.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/slack.desktop
chown 1000:1000 $HOME/Desktop/slack.desktop

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
