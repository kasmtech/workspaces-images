#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox --disable-gpu --user-data-dir --no-first-run"

if [ "$DISTRO" = centos ]; then
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
  yum localinstall -y google-chrome-stable_current_x86_64.rpm
  rm google-chrome-stable_current_x86_64.rpm
else
  apt-get update
  apt-get remove -y chromium-browser-l10n chromium-codecs-ffmpeg chromium-browser

  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  apt-get install -y ./google-chrome-stable_current_amd64.deb
  rm google-chrome-stable_current_amd64.deb
fi

sed -i 's/-stable//g' /usr/share/applications/google-chrome.desktop

cp /usr/share/applications/google-chrome.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/google-chrome.desktop

mv /usr/bin/google-chrome /usr/bin/google-chrome-orig
cat >/usr/bin/google-chrome <<EOL
#!/usr/bin/env bash
/opt/google/chrome/google-chrome ${CHROME_ARGS} "\$@"
EOL
chmod +x /usr/bin/google-chrome
cp /usr/bin/google-chrome /usr/bin/chrome

if [ "$DISTRO" = centos ]; then
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
