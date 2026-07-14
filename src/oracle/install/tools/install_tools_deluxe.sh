#!/usr/bin/env bash
set -ex

if [ -f /usr/bin/dnf ]; then
  # Pin glibc-locale-source/glibc-langpack-en to the glibc already in the base
  # image. The base ships a version of glibc; leaving them
  # unpinned makes dnf try to install versions which conflicts
  # with the installed glibc-common and the langpacks.
  glibc_ver="$(rpm -q --qf '%{version}-%{release}' glibc)"
  dnf install -y vlc git tmux xz "glibc-locale-source-${glibc_ver}" "glibc-langpack-en-${glibc_ver}"
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
else
  yum-config-manager --enable ol7_optional_latest
  yum install -y vlc git tmux
  if [ -z ${SKIP_CLEAN+x} ]; then
    yum clean all
  fi
fi

