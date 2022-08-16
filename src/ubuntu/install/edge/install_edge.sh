#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"

apt-get update

EDGE_BUILD=$(curl -q https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-dev/ | grep href | grep .deb | sed 's/.*href="//g'  | cut -d '"' -f1 | sort --version-sort | tail -1)

wget -q -O edge.deb https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-dev/$EDGE_BUILD
apt-get install -y ./edge.deb
rm edge.deb

cp /usr/share/applications/microsoft-edge-dev.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/microsoft-edge-dev.desktop

mv /usr/bin/microsoft-edge-dev  /usr/bin/microsoft-edge-dev-orig
cat >/usr/bin/microsoft-edge-dev <<EOL
#!/usr/bin/env bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/microsoft-edge-dev/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/microsoft-edge-dev/Default/Preferences
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Edge with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /opt/microsoft/msedge-dev/microsoft-edge ${CHROME_ARGS} "\$@" 
else
    echo "Starting Edge"
    /opt/microsoft/msedge-dev/microsoft-edge ${CHROME_ARGS} "\$@"
fi
EOL
chmod +x /usr/bin/microsoft-edge-dev

sed -i 's@exec -a "$0" "$HERE/microsoft-edge" "$\@"@@g' /usr/bin/x-www-browser
cat >>/usr/bin/x-www-browser <<EOL
exec -a "\$0" "\$HERE/microsoft-edge" "${CHROME_ARGS}"  "\$@"
EOL


mkdir -p /etc/opt/edge/policies/managed/
cat >>/etc/opt/edge/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL

# Vanilla Chrome looks for policies in /etc/opt/chrome/policies/managed which is used by web filtering.
#   Create a symlink here so filter is applied to edge as well.
mkdir -p /etc/opt/chrome/policies/
ln -s /etc/opt/edge/policies/managed  /etc/opt/chrome/policies/

