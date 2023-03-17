#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox  --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"

apk add --no-cache \
  chromium 

if [ "$(arch)" == "x86_64" ]; then
  apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    virtualgl
fi

REAL_BIN=chromium

cp /usr/share/applications/chromium.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/chromium.desktop

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

cat >> $HOME/.config/mimeapps.list <<EOF
    [Default Applications]
    x-scheme-handler/http=chromium.desktop
    x-scheme-handler/https=chromium.desktop
    x-scheme-handler/ftp=chromium.desktop
    x-scheme-handler/chrome=chromium.desktop
    text/html=chromium.desktop
    application/x-extension-htm=chromium.desktop
    application/x-extension-html=chromium.desktop
    application/x-extension-shtml=chromium.desktop
    application/xhtml+xml=chromium.desktop
    application/x-extension-xhtml=chromium.desktop
    application/x-extension-xht=chromium.desktop
EOF

mkdir -p /etc/chromium/policies/managed/
cat >>/etc/chromium/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL
