#!/usr/bin/env bash
set -ex

if [ "${DISTRO}" == "opensuse" ]; then
  zypper search -t package "*-lang" | awk '{print $2}' > /tmp/lang-packages
  rpm -qa --queryformat "%{NAME}\n" > /tmp/installed-packages
  to_install=""
  while read p; do
    if grep -qw "^${p}-lang$" /tmp/lang-packages; then
      to_install="$to_install ${p}-lang"
    fi
  done </tmp/installed-packages
  if [ -n "$to_install" ]; then
    zypper -n install $to_install
  fi
elif [ "${DISTRO}" == "alpine" ]; then
  apk add --no-cache \
    lang
fi
