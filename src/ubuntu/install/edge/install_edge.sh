#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"

apt-get update

EDGE_BUILD=$(curl -q https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/ | grep href | grep .deb | sed 's/.*href="//g'  | cut -d '"' -f1 | sort --version-sort | tail -1)

wget -q -O edge.deb https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/$EDGE_BUILD
apt-get install -y ./edge.deb
rm edge.deb

cp /usr/share/applications/microsoft-edge.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/microsoft-edge.desktop
chmod +x $HOME/Desktop/microsoft-edge.desktop

mv /usr/bin/microsoft-edge-stable  /usr/bin/microsoft-edge-stable-orig
cat >/usr/bin/microsoft-edge-stable <<EOL
#!/usr/bin/env bash

supports_vulkan() {
  # Needs the CLI tool
  command -v vulkaninfo >/dev/null 2>&1 || return 1

  # Look for any non-CPU device
  DISPLAY= vulkaninfo --summary 2>/dev/null |
    grep -qE 'PHYSICAL_DEVICE_TYPE_(INTEGRATED_GPU|DISCRETE_GPU|VIRTUAL_GPU)'
}

sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/microsoft-edge/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/microsoft-edge/Default/Preferences

VULKAN_FLAGS=
if supports_vulkan; then
  VULKAN_FLAGS="--use-angle=vulkan"
  echo 'vulkan supported'
fi

if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Edge with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /opt/microsoft/msedge/microsoft-edge ${CHROME_ARGS} "\${VULKAN_FLAGS}" "\$@" 
else
    echo "Starting Edge"
    /opt/microsoft/msedge/microsoft-edge ${CHROME_ARGS} "\${VULKAN_FLAGS}" "\$@"
fi
EOL
chmod +x /usr/bin/microsoft-edge-stable

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
mkdir -p /etc/opt/edge
ln -s /etc/opt/chrome/policies /etc/opt/edge/policies
mkdir -p /etc/opt/edge/policies/managed

if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
