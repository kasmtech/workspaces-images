#!/usr/bin/env bash
set -ex

if [ "$(arch)" == "aarch64" ] ; then
  echo "Sublime Text not supported on arm64 for RPM based distros, skipping installation"
  exit 0
fi

rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg

if [ "${DISTRO}" == "oracle8" ]; then
  dnf config-manager --add-repo https://download.sublimetext.com/rpm/stable/$(arch)/sublime-text.repo
  dnf install -y sublime-text
  dnf clean all
else
  yum-config-manager --add-repo https://download.sublimetext.com/rpm/stable/$(arch)/sublime-text.repo
  yum install -y sublime-text
  yum clean all
fi
cp /usr/share/applications/sublime_text.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/sublime_text.desktop
chown 1000:1000 $HOME/Desktop/sublime_text.desktop
