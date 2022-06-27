#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --check-for-update-interval=31449600"

apt-get update
apt install -y  apt-transport-https curl

curl -s https://brave-browser-apt-release.s3.brave.com/brave-core.asc |  apt-key --keyring /etc/apt/trusted.gpg.d/brave-browser-release.gpg add -

echo "deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" |  tee /etc/apt/sources.list.d/brave-browser-release.list

apt update

apt install -y  brave-browser

sed -i 's/-stable//g' /usr/share/applications/brave-browser.desktop

cp /usr/share/applications/brave-browser.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/brave-browser.desktop

mv /usr/bin/brave-browser /usr/bin/brave-browser-orig
cat >/usr/bin/brave-browser <<EOL
#!/usr/bin/env bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Brave with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /opt/brave.com/brave/brave-browser ${CHROME_ARGS} "\$@" 
else
    echo "Starting Brave"
    /opt/brave.com/brave/brave-browser ${CHROME_ARGS} "\$@"
fi
EOL
chmod +x /usr/bin/brave-browser
cp /usr/bin/brave-browser /usr/bin/brave

sed -i 's@exec -a "$0" "$HERE/brave" "$\@"@@g' /usr/bin/x-www-browser
cat >>/usr/bin/x-www-browser <<EOL
exec -a "\$0" "\$HERE/brave" "${CHROME_ARGS}"  "\$@"
EOL

mkdir -p /etc/brave/policies/managed/
# Vanilla Chrome looks for policies in /etc/opt/chrome/policies/managed which is used by web filtering.
#   Create a symlink here so filter is applied to brave as well.
mkdir -p /etc/opt/chrome/policies/
ln -s /etc/brave/policies/managed /etc/opt/chrome/policies/
cat >>/etc/brave/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL
cat >>/etc/brave/policies/managed/disable_tor.json <<EOL
{"TorDisabled": true}
EOL

