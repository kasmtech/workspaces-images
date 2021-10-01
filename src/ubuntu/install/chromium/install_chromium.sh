#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox  --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"

if [ "$DISTRO" = centos ]; then
  yum install -y chromium
  yum clean all
else
  apt-get update
  apt-get install -y software-properties-common
  apt-get remove -y chromium-browser-l10n chromium-codecs-ffmpeg chromium-browser
  apt-get install -y chromium-browser
fi

sed -i 's/-stable//g' /usr/share/applications/chromium-browser.desktop

cp /usr/share/applications/chromium-browser.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/chromium-browser.desktop

mv /usr/bin/chromium-browser /usr/bin/chromium-browser-orig
cat >/usr/bin/chromium-browser <<EOL
#!/usr/bin/env bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/chromium/Default/Preferences
/usr/bin/chromium-browser-orig ${CHROME_ARGS} "\$@"
EOL
chmod +x /usr/bin/chromium-browser
cp /usr/bin/chromium-browser /usr/bin/chromium

if [ "$DISTRO" = centos ]; then
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
