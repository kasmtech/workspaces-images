#!/usr/bin/env bash
set -ex

if [ "$(arch)" == "aarch64" ] ; then
  echo "Sublime Text not supported on arm64 for RPM based distros, skipping installation"
  exit 0
fi

if [[ "${DISTRO}" == @(rhel9|almalinux9|oracle9|rockylinux9) ]]; then
  # Temporarily enable SHA1 in crypto policies to allow importing Sublime's GPG key (can remove this when the gpg key is updated with SHA256 or stronger digest)
  # Start of SHA1 policy workaround
  SHA1_POLICY_ORIGINAL=""
  SHA1_POLICY_ENABLED=0
  if command -v update-crypto-policies >/dev/null 2>&1; then
    SHA1_POLICY_ORIGINAL=$(update-crypto-policies --show | tr -d '\n')
    if [[ -n "${SHA1_POLICY_ORIGINAL}" && "${SHA1_POLICY_ORIGINAL}" != *":SHA1"* ]]; then
      update-crypto-policies --set "${SHA1_POLICY_ORIGINAL}:SHA1"
      SHA1_POLICY_ENABLED=1
    fi
  fi

  cleanup_sha1_policy() {
    if [[ ${SHA1_POLICY_ENABLED} -eq 1 ]]; then
      update-crypto-policies --set "${SHA1_POLICY_ORIGINAL}"
    fi
  }
  trap cleanup_sha1_policy EXIT
  # End of SHA1 policy workaround
fi

rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg

if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|rhel9|almalinux9|almalinux8|fedora39|fedora40|fedora41) ]]; then
  if [[ "${DISTRO}" == "fedora41" ]]; then
    dnf config-manager addrepo --from-repofile=https://download.sublimetext.com/rpm/stable/$(arch)/sublime-text.repo
  else
    dnf config-manager --add-repo https://download.sublimetext.com/rpm/stable/$(arch)/sublime-text.repo
  fi
  # Remove the gpgkey line from repo file since we manually imported the key
  sed -i '/^gpgkey=/d' /etc/yum.repos.d/sublime-text.repo
  dnf install -y sublime-text
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
else
  yum-config-manager --add-repo https://download.sublimetext.com/rpm/stable/$(arch)/sublime-text.repo
  # Remove the gpgkey line from repo file since we manually imported the key
  sed -i '/^gpgkey=/d' /etc/yum.repos.d/sublime-text.repo
  yum install -y sublime-text
  if [ -z ${SKIP_CLEAN+x} ]; then
    yum clean all
  fi
fi
cp /usr/share/applications/sublime_text.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/sublime_text.desktop
chown 1000:1000 $HOME/Desktop/sublime_text.desktop
