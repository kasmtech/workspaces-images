#!/bin/bash
set -ex

apt-get update && apt-get install -y sudo wget zsh

id -u kasm-user &>/dev/null || useradd -m -s /bin/bash kasm-user
echo 'kasm-user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/kasm-user
chmod 0440 /etc/sudoers.d/kasm-user

cd /opt/
wget https://raw.githubusercontent.com/tracelabs/tlosint-vm/main/scripts/tlosint-tools.sh
chmod +x tlosint-tools.sh
su - kasm-user -c '/opt/tlosint-tools.sh'

su - kasm-user -c "$INST_SCRIPTS/tracelabs/fix-tlosint.sh"

# Rerunning the tlosint script to invoke it validation again after the fixes
su - kasm-user -c '/opt/tlosint-tools.sh'

# Apply the Trace Labs desktop overlays (wallpaper, theme, desktop icons, menu
# categories) that tlosint-tools.sh does NOT install.
TL_USER=kasm-user bash "$INST_SCRIPTS/tracelabs/apply_tracelabs_overlays.sh"

if [ -d /home/kasm-user ]; then
  cp -a /home/kasm-user/. /home/kasm-default-profile/
  chown -R 1000:0 /home/kasm-default-profile
fi

if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi