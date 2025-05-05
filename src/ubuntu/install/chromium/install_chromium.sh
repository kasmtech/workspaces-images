#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox  --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [[ "${DISTRO}" == @(debian|opensuse|ubuntu) ]] && [ ${ARCH} = 'amd64' ] && [ ! -z ${SKIP_CLEAN+x} ]; then
  echo "not installing chromium on x86_64 desktop build"
  exit 0
fi

if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|rhel9|almalinux9|almalinux8|fedora39|fedora40) ]]; then
  dnf install -y chromium
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
elif [ "${DISTRO}" == "opensuse" ]; then
  zypper install -yn chromium
  if [ -z ${SKIP_CLEAN+x} ]; then
    zypper clean --all
  fi
elif grep -q "ID=debian" /etc/os-release || grep -q "ID=kali" /etc/os-release || grep -q "ID=parrot" /etc/os-release; then
  apt-get update
  apt-get install -y chromium
  if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
  fi
else
  apt-get update
  apt-get install -y software-properties-common ttf-mscorefonts-installer
  apt-get remove -y chromium-browser-l10n chromium-codecs-ffmpeg chromium-browser

  # Install from debian bookworm repos
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://ftp-master.debian.org/keys/archive-key-12.asc | sudo tee /etc/apt/keyrings/debian-archive-key-12.asc
  echo "deb [signed-by=/etc/apt/keyrings/debian-archive-key-12.asc] http://deb.debian.org/debian bookworm main" | sudo tee /etc/apt/sources.list.d/debian-bookworm.list
  echo -e "Package: *\nPin: release a=bookworm\nPin-Priority: 100" | sudo tee /etc/apt/preferences.d/debian-bookworm
  apt-get update
  apt install -y chromium --no-install-recommends

  # Cleanup debian bookworm repos
  rm /etc/apt/sources.list.d/debian-bookworm.list
  rm /etc/apt/preferences.d/debian-bookworm
  rm /etc/apt/keyrings/debian-archive-key-12.asc
  apt-get update

  if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
  fi

fi

if grep -q "ID=debian" /etc/os-release || grep -q "ID=kali" /etc/os-release || grep -q "ID=parrot" /etc/os-release || grep -q "ID=ubuntu" /etc/os-release; then
  REAL_BIN=chromium
else
  REAL_BIN=chromium-browser
fi


sed -i 's/-stable//g' /usr/share/applications/${REAL_BIN}.desktop

if ! grep -q "ID=kali" /etc/os-release; then
  cp /usr/share/applications/${REAL_BIN}.desktop $HOME/Desktop/
  chmod +x $HOME/Desktop/${REAL_BIN}.desktop
  chown 1000:1000 $HOME/Desktop/${REAL_BIN}.desktop
fi

mv /usr/bin/${REAL_BIN} /usr/bin/${REAL_BIN}-orig
cat >/usr/bin/${REAL_BIN} <<EOL
#!/usr/bin/env bash
if ! pgrep chromium > /dev/null;then
  rm -f \$HOME/.config/chromium/Singleton*
fi
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/chromium/Default/Preferences
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Chrome with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /usr/bin/${REAL_BIN}-orig ${CHROME_ARGS} "\$@" 
else
    echo "Starting Chrome"
    /usr/bin/${REAL_BIN}-orig ${CHROME_ARGS} "\$@"
fi
EOL
chmod +x /usr/bin/${REAL_BIN}

if [ "${DISTRO}" != "opensuse" ] && ! grep -q "ID=debian" /etc/os-release && ! grep -q "ID=kali" /etc/os-release && ! grep -q "ID=parrot" /etc/os-release && ! grep -q "ID=ubuntu" /etc/os-release; then
  cp /usr/bin/chromium-browser /usr/bin/chromium
fi

if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|rhel9|almalinux9|almalinux8|opensuse|fedora39|fedora40) ]]; then
  cat >> $HOME/.config/mimeapps.list <<EOF
    [Default Applications]
    x-scheme-handler/http=${REAL_BIN}.desktop
    x-scheme-handler/https=${REAL_BIN}.desktop
    x-scheme-handler/ftp=${REAL_BIN}.desktop
    x-scheme-handler/chrome=${REAL_BIN}.desktop
    text/html=${REAL_BIN}.desktop
    application/x-extension-htm=${REAL_BIN}.desktop
    application/x-extension-html=${REAL_BIN}.desktop
    application/x-extension-shtml=${REAL_BIN}.desktop
    application/xhtml+xml=${REAL_BIN}.desktop
    application/x-extension-xhtml=${REAL_BIN}.desktop
    application/x-extension-xht=${REAL_BIN}.desktop
EOF
else
  sed -i 's@exec -a "$0" "$HERE/chromium-browser" "$\@"@@g' /usr/bin/x-www-browser
  cat >>/usr/bin/x-www-browser <<EOL
  exec -a "\$0" "\$HERE/chromium" "${CHROME_ARGS}"  "\$@"
EOL
fi

mkdir -p /etc/chromium/policies/managed/
cat >>/etc/chromium/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
