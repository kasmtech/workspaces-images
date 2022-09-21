#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox  --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [[ "${DISTRO}" == @(centos|oracle7|oracle8) ]]; then
  if [ "${DISTRO}" == "oracle8" ]; then
    dnf install -y chromium
    dnf clean all
  else
    yum install -y chromium
    yum clean all
  fi
elif [ "${DISTRO}" == "opensuse" ]; then
  zypper install -yn chromium
  zypper clean --all
else
  apt-get update
  apt-get install -y software-properties-common ttf-mscorefonts-installer
  apt-get remove -y chromium-browser-l10n chromium-codecs-ffmpeg chromium-browser
  
  # Chromium on Ubuntu 19.10 or newer uses snap to install which is not
  # currently compatible with docker containers. The new install will pull
  # deb files from archive.ubuntu.com for ubuntu 18.04 and install them.
  # This will work until 18.04 goes to an unsupported status.
  if [[ ${ARCH} == "amd64" ]] ;
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
fi

sed -i 's/-stable//g' /usr/share/applications/chromium-browser.desktop

cp /usr/share/applications/chromium-browser.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/chromium-browser.desktop

mv /usr/bin/chromium-browser /usr/bin/chromium-browser-orig
cat >/usr/bin/chromium-browser <<EOL
#!/usr/bin/env bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/chromium/Default/Preferences
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Chrome with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /usr/bin/chromium-browser-orig ${CHROME_ARGS} "\$@" 
else
    echo "Starting Chrome"
    /usr/bin/chromium-browser-orig ${CHROME_ARGS} "\$@"
fi
EOL
chmod +x /usr/bin/chromium-browser

if [ "${DISTRO}" != "opensuse" ]; then
  cp /usr/bin/chromium-browser /usr/bin/chromium
fi

if [[ "${DISTRO}" == @(centos|oracle7|oracle8|opensuse) ]]; then
  cat >> $HOME/.config/mimeapps.list <<EOF
    [Default Applications]
    x-scheme-handler/http=chromium-browser.desktop
    x-scheme-handler/https=chromium-browser.desktop
    x-scheme-handler/ftp=chromium-browser.desktop
    x-scheme-handler/chrome=chromium-browser.desktop
    text/html=chromium-browser.desktop
    application/x-extension-htm=chromium-browser.desktop
    application/x-extension-html=chromium-browser.desktop
    application/x-extension-shtml=chromium-browser.desktop
    application/xhtml+xml=chromium-browser.desktop
    application/x-extension-xhtml=chromium-browser.desktop
    application/x-extension-xht=chromium-browser.desktop
EOF
else
  sed -i 's@exec -a "$0" "$HERE/chromium" "$\@"@@g' /usr/bin/x-www-browser
  cat >>/usr/bin/x-www-browser <<EOL
  exec -a "\$0" "\$HERE/chromium" "${CHROME_ARGS}"  "\$@"
EOL
fi

mkdir -p /etc/chromium/policies/managed/
cat >>/etc/chromium/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL
