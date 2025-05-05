#!/usr/bin/env bash
set -ex

if [ "$(arch)" == "aarch64" ] ; then
  echo "Sublime Text not supported on arm64 for RPM based distros, skipping installation"
  exit 0
fi

rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg

zypper addrepo -g -f https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo
zypper install -yn sublime-text
if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
cp /usr/share/applications/sublime_text.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/sublime_text.desktop
chown 1000:1000 $HOME/Desktop/sublime_text.desktop
