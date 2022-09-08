#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"
CHROME_VERSION=$1

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "$ARCH" == "arm64" ] ; then
  echo "Chrome not supported on arm64, skipping Chrome installation"
  exit 0
fi	

if [[ "${DISTRO}" == @(centos|oracle7|oracle8) ]]; then
  if [ ! -z "${CHROME_VERSION}" ]; then
    wget https://dl.google.com/linux/chrome/rpm/stable/x86_64/google-chrome-stable-${CHROME_VERSION}.x86_64.rpm -O chrome.rpm
  else
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm -O chrome.rpm
  fi
  if [ "${DISTRO}" == "oracle8" ]; then
    dnf localinstall -y chrome.rpm
    dnf clean all
  else
    yum localinstall -y chrome.rpm
    yum clean all
  fi
  rm chrome.rpm
elif [ "${DISTRO}" == "opensuse" ]; then
  zypper ar http://dl.google.com/linux/chrome/rpm/stable/x86_64 Google-Chrome
  wget https://dl.google.com/linux/linux_signing_key.pub
  rpm --import linux_signing_key.pub
  rm linux_signing_key.pub
  zypper install -yn google-chrome-stable
  zypper clean --all
else
  apt-get update
  apt-get remove -y chromium-browser-l10n chromium-codecs-ffmpeg chromium-browser
  if [ ! -z "${CHROME_VERSION}" ]; then
    wget https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_amd64.deb -O chrome.deb
  else
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O chrome.deb
  fi
  apt-get install -y ./chrome.deb
  rm chrome.deb
fi

sed -i 's/-stable//g' /usr/share/applications/google-chrome.desktop

cp /usr/share/applications/google-chrome.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/google-chrome.desktop
chmod +x $HOME/Desktop/google-chrome.desktop

mv /usr/bin/google-chrome /usr/bin/google-chrome-orig
cat >/usr/bin/google-chrome <<EOL
#!/usr/bin/env bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/google-chrome/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/google-chrome/Default/Preferences
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Chrome with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /opt/google/chrome/google-chrome ${CHROME_ARGS} "\$@" 
else
    echo "Starting Chrome"
    /opt/google/chrome/google-chrome ${CHROME_ARGS} "\$@"
fi
EOL
chmod +x /usr/bin/google-chrome
cp /usr/bin/google-chrome /usr/bin/chrome

if [[ "${DISTRO}" == @(centos|oracle7|oracle8|opensuse) ]]; then
  cat >> $HOME/.config/mimeapps.list <<EOF
    [Default Applications]
    x-scheme-handler/http=google-chrome.desktop
    x-scheme-handler/https=google-chrome.desktop
    x-scheme-handler/ftp=google-chrome.desktop
    x-scheme-handler/chrome=google-chrome.desktop
    text/html=google-chrome.desktop
    application/x-extension-htm=google-chrome.desktop
    application/x-extension-html=google-chrome.desktop
    application/x-extension-shtml=google-chrome.desktop
    application/xhtml+xml=google-chrome.desktop
    application/x-extension-xhtml=google-chrome.desktop
    application/x-extension-xht=google-chrome.desktop
EOF
else
  sed -i 's@exec -a "$0" "$HERE/chrome" "$\@"@@g' /usr/bin/x-www-browser
  cat >>/usr/bin/x-www-browser <<EOL
  exec -a "\$0" "\$HERE/chrome" "${CHROME_ARGS}"  "\$@"
EOL
fi

mkdir -p /etc/opt/chrome/policies/managed/
cat >>/etc/opt/chrome/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL
