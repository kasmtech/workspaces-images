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

DEVICE_EXTENSION_DIR="/dockerstartup/device_extension/workspace-device-extension"
DEVICE_EXTENSION_CRX="\${DEVICE_EXTENSION_DIR}.crx"
EXTENSION_FLAGS=
# A packed CRX is registered as an external extension at build time, only fall back to
#   loading the unpacked extension when the browser build still allows it.
if [ ! -f "\${DEVICE_EXTENSION_CRX}" ] && [ -d "\${DEVICE_EXTENSION_DIR}" ]; then
  EXTENSION_FLAGS="--load-extension=\${DEVICE_EXTENSION_DIR}"
fi

if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Edge with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /opt/microsoft/msedge/microsoft-edge ${CHROME_ARGS} \${VULKAN_FLAGS} \${EXTENSION_FLAGS} "\$@"
else
    echo "Starting Edge"
    /opt/microsoft/msedge/microsoft-edge ${CHROME_ARGS} \${VULKAN_FLAGS} \${EXTENSION_FLAGS} "\$@"
fi
EOL
chmod +x /usr/bin/microsoft-edge-stable

# Register the Kasm workspace device extension as an external extension.
register_device_extension() {
  DEVICE_EXTENSION_DIR="${DEVICE_EXTENSION_DIR:-/dockerstartup/device_extension/workspace-device-extension}"
  DEVICE_EXTENSION_CRX="${DEVICE_EXTENSION_CRX:-${DEVICE_EXTENSION_DIR}.crx}"
  DEVICE_EXTENSION_MANIFEST="${DEVICE_EXTENSION_DIR}/manifest.json"

  if [ ! -f "${DEVICE_EXTENSION_CRX}" ] || [ ! -f "${DEVICE_EXTENSION_MANIFEST}" ]; then
    echo "No packed device extension at ${DEVICE_EXTENSION_CRX}, skipping external extension registration"
    return 0
  fi

  DEVICE_EXTENSION_KEY=$(sed -n 's/.*"key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${DEVICE_EXTENSION_MANIFEST}")
  DEVICE_EXTENSION_VERSION=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${DEVICE_EXTENSION_MANIFEST}")
  if [ -z "${DEVICE_EXTENSION_KEY}" ] || [ -z "${DEVICE_EXTENSION_VERSION}" ]; then
    echo "Device extension manifest has no key or version, skipping external extension registration"
    return 0
  fi

  DEVICE_EXTENSION_ID=$(printf '%s' "${DEVICE_EXTENSION_KEY}" | base64 -d | sha256sum | cut -c1-32 | tr '0-9a-f' 'a-p')

  for DEVICE_EXTENSION_TARGET in "$@"; do
    mkdir -p "${DEVICE_EXTENSION_TARGET}"
    cat >"${DEVICE_EXTENSION_TARGET}/${DEVICE_EXTENSION_ID}.json" <<EOF
    {
      "external_crx": "${DEVICE_EXTENSION_CRX}",
      "external_version": "${DEVICE_EXTENSION_VERSION}"
    }
EOF
  done

  # Keep the extension installable if a deployment applies an extension blocklist.
  if [ -n "${DEVICE_EXTENSION_POLICY_DIR:-}" ]; then
    mkdir -p "${DEVICE_EXTENSION_POLICY_DIR}"
    cat >"${DEVICE_EXTENSION_POLICY_DIR}/kasm_device_extension.json" <<EOF
    {
      "ExtensionInstallAllowlist": ["${DEVICE_EXTENSION_ID}"]
    }
EOF
  fi

  echo "Registered device extension ${DEVICE_EXTENSION_ID} version ${DEVICE_EXTENSION_VERSION}"
}


sed -i 's@exec -a "$0" "$HERE/microsoft-edge" "$\@"@@g' /usr/bin/x-www-browser
cat >>/usr/bin/x-www-browser <<EOL
exec -a "\$0" "\$HERE/microsoft-edge" "${CHROME_ARGS}"  "\$@"
EOL


mkdir -p /etc/opt/edge/policies/managed/
cat >>/etc/opt/edge/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL

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

DEVICE_EXTENSION_POLICY_DIR=/etc/opt/edge/policies/managed \
  register_device_extension /usr/share/microsoft-edge/extensions /opt/microsoft/msedge/extensions
