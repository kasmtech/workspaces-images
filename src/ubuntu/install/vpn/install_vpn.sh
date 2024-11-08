#!/usr/bin/env bash
set -ex

# Install OpenVPN/Wireguard deps
if [[ "${DISTRO}" == @(ubuntu|kali|debian|parrotos6) ]]; then
  echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections
  apt-get update
  apt-get install -y --no-install-recommends \
    openvpn \
    resolvconf \
    wireguard-tools \
    zenity \
    jq
elif [ "${DISTRO}" == "alpine" ]; then
  apk add --no-cache \
    openresolv \
    openvpn \
    tailscale \
    wireguard-tools \
    zenity \
    jq
elif [[ "${DISTRO}" == @(oracle8|oracle9|rhel9|rockylinux8|rockylinux9|almalinux8|almalinux9) ]] ; then
  dnf install -y epel-release
  dnf install -y \
    openvpn \
    wireguard-tools \
    jq
elif [[ "${DISTRO}" == @(fedora39|fedora40) ]] ; then
  dnf install -y \
    openresolv \
    openvpn \
    wireguard-tools \
    zenity \
    jq
elif [ "${DISTRO}" == "opensuse" ]; then
  zypper install -y \
    openresolv \
    openvpn \
    wireguard-tools \
    zenity \
    jq
fi

# Install tailscale
FLAVOR=$(cat /etc/os-release | awk -F'=' '/^VERSION_CODENAME=/ {print $2}' | sed 's/""//g')
ID=$(cat /etc/os-release | awk -F'=' '/^ID=/ {print $2}')
VERSION=$(cat /etc/os-release | awk -F'"' '/^VERSION_ID=/ {print $2}')
VERSION2=$(cat /etc/os-release | awk -F'=' '/^VERSION_ID=/ {print $2}')
if [[ "${FLAVOR}" ]]; then
  FLAVOR=$(echo ${FLAVOR} | sed -e 's/ara/sid/g' -e 's/kali-rolling/sid/g')
  ID=$(echo ${ID} | sed -e 's/kali/debian/g' -e 's/parrot/debian/g')
  mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkgs.tailscale.com/stable/${ID}/${FLAVOR}.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/${ID}/${FLAVOR}.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
  apt-get update
  apt-get install -y --no-install-recommends tailscale
else
  if [[ "${VERSION}" == "8" ]] || [[ "${VERSION}" = "8*" ]]; then
    dnf install -y 'dnf-command(config-manager)'
    dnf config-manager --add-repo https://pkgs.tailscale.com/stable/centos/8/tailscale.repo
    dnf install -y tailscale
  elif [[ "${VERSION}" == "9" ]] || [[ "${VERSION}" = "9*" ]]; then
    dnf install -y 'dnf-command(config-manager)'
    dnf config-manager --add-repo https://pkgs.tailscale.com/stable/centos/9/tailscale.repo
    dnf install -y tailscale
  elif [[ "${ID}" == "fedora" ]]; then
    dnf install -y 'dnf-command(config-manager)'
    dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/${VERSION2}/tailscale.repo
    dnf install -y tailscale
  elif [[ "${ID}" == "\"opensuse-leap\"" ]]; then
    zypper ar -g -r https://pkgs.tailscale.com/stable/opensuse/leap/15.5/tailscale.repo
    zypper --gpg-auto-import-keys ref
    zypper install -ny tailscale
  fi
fi

# Tweaks to wg-up
sed -i '/cmd sysctl -q/d' $(which wg-quick)

# Copy startup script
cp ${INST_DIR}/ubuntu/install/vpn/start_vpn.sh /dockerstartup/start_vpn.sh
chmod +x /dockerstartup/start_vpn.sh
