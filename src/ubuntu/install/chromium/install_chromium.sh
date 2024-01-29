#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox  --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [[ "${DISTRO}" == @(debian|opensuse|ubuntu) ]] && [ ${ARCH} = 'amd64' ] && [ ! -z ${SKIP_CLEAN+x} ]; then
  echo "not installing chromium on x86_64 desktop build"
  exit 0
fi

if [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
  if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
    dnf install -y chromium
    if [ -z ${SKIP_CLEAN+x} ]; then
      dnf clean all
    fi
  else
    yum install -y chromium
    if [ -z ${SKIP_CLEAN+x} ]; then
      yum clean all
    fi
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
  
  # Chromium on Ubuntu 19.10 or newer uses snap to install which is not
  # currently compatible with docker containers. The new install will pull
  # deb files from archive.ubuntu.com for ubuntu 18.04 and install them.
  # This will work until 18.04 goes to an unsupported status.
  if [ ${ARCH} = 'amd64' ] ;
  then
    chrome_url="http://archive.ubuntu.com/ubuntu/pool/universe/c/chromium-browser/"
  else
    chrome_url="http://ports.ubuntu.com/pool/universe/c/chromium-browser/"
  fi

  chromium_codecs_data=$(curl ${chrome_url})
  chromium_codecs_data=$(grep "chromium-codecs-ffmpeg-extra_" <<< "${chromium_codecs_data}")
  chromium_codecs_data=$(grep "18\.04" <<< "${chromium_codecs_data}")
  chromium_codecs_data=$(grep "${ARCH}" <<< "${chromium_codecs_data}")
  chromium_codecs_data=$(sed -n 's/.*<a href="//p' <<< "${chromium_codecs_data}")
  chromium_codecs_data=$(sed -n 's/">.*//p' <<< "${chromium_codecs_data}")
  echo "Chromium codec deb to download: ${chromium_codecs_data}"

  chromium_data=$(curl ${chrome_url})
  chromium_data=$(grep "chromium-browser_" <<< "${chromium_data}")
  chromium_data=$(grep "18\.04" <<< "${chromium_data}")
  chromium_data=$(grep "${ARCH}" <<< "${chromium_data}")
  chromium_data=$(sed -n 's/.*<a href="//p' <<< "${chromium_data}")
  chromium_data=$(sed -n 's/">.*//p' <<< "${chromium_data}")
  echo "Chromium browser deb to download: ${chromium_data}"

  echo "The things to download"
  echo "${chrome_url}${chromium_codecs_data}"
  echo "${chrome_url}${chromium_data}"

  wget "${chrome_url}${chromium_codecs_data}"
  wget "${chrome_url}${chromium_data}"

  apt-get install -y ./"${chromium_codecs_data}"
  apt-get install -y ./"${chromium_data}"

  rm "${chromium_codecs_data}"
  rm "${chromium_data}"
  if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
  fi
fi

if grep -q "ID=debian" /etc/os-release || grep -q "ID=kali" /etc/os-release || grep -q "ID=parrot" /etc/os-release; then
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

if [ "${DISTRO}" != "opensuse" ] && ! grep -q "ID=debian" /etc/os-release && ! grep -q "ID=kali" /etc/os-release && ! grep -q "ID=parrot" /etc/os-release; then
  cp /usr/bin/chromium-browser /usr/bin/chromium
fi

if [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|opensuse|fedora37|fedora38|fedora39) ]]; then
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
