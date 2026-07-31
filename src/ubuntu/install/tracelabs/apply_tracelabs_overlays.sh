#!/bin/bash
#
# Script to apply Tracelabs overlays to the image
set -euo pipefail

log() { printf '[tl-overlays] %s\n' "$*"; }

TL_USER="${TL_USER:-kasm-user}"
TL_HOME="$(getent passwd "$TL_USER" | cut -d: -f6)"
TL_HOME="${TL_HOME:-/home/$TL_USER}"

# The upstream tlosint-tools.sh adds the apt.vulns.xyz repo (for sn0int) which can be out-of-sync,
# since rsync doesn't need it, continuing
apt-get update || log "apt-get update reported errors (e.g. the broken vulns.xyz repo) - continuing"
apt-get install -y rsync git

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

log "Downloading the tlosint-vm source for the overlay tree"
TLOSINT_RELEASE="2026.07"
TLOSINT_SCRIPT_URL="https://github.com/tracelabs/tlosint-vm/archive/refs/tags/${TLOSINT_RELEASE}.tar.gz"

wget -P "${WORK}" "${TLOSINT_SCRIPT_URL}"
cd "${WORK}"
tar -xzf "${TLOSINT_RELEASE}.tar.gz"

OVERLAY="$WORK/tlosint-vm-${TLOSINT_RELEASE}/overlays/tl-overlays"

log "Applying /etc and /usr overlays"
rsync -a "$OVERLAY/etc/" /etc/
rsync -a "$OVERLAY/usr/" /usr/

if [[ -f /usr/share/backgrounds/tracelabs/tracelabs.png ]]; then
  log "Setting Kasm default wallpaper to the Trace Labs background"
  cp /usr/share/backgrounds/tracelabs/tracelabs.png /usr/share/backgrounds/bg_default.png
fi

if [[ -d /etc/skel ]]; then
  log "Seeding $TL_HOME from /etc/skel (Desktop icons, TL-Vault, etc.)"
  rsync -a /etc/skel/ "$TL_HOME/"
  # .desktop launchers need the executable bit to be trusted by xfdesktop
  find "$TL_HOME/Desktop" -maxdepth 1 -name '*.desktop' -exec chmod +x {} \; 2>/dev/null || true
  chown -R "$TL_USER":"$TL_USER" "$TL_HOME"
fi

# Remove the duplicate.
rm -f /usr/share/applications/chromium.desktop

log "Overlays applied."
