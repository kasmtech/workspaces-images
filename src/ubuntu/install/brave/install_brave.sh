#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
CHROME_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --check-for-update-interval=31449600"

apt-get update
apt install -y  apt-transport-https curl

curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"| tee /etc/apt/sources.list.d/brave-browser-release.list

apt update

apt install -y  brave-browser

sed -i 's/-stable//g' /usr/share/applications/brave-browser.desktop

cp /usr/share/applications/brave-browser.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/brave-browser.desktop
chmod +x $HOME/Desktop/brave-browser.desktop

mv /usr/bin/brave-browser /usr/bin/brave-browser-orig
cat >/usr/bin/brave-browser <<EOL
#!/usr/bin/env bash

supports_vulkan() {
  # Needs the CLI tool
  command -v vulkaninfo >/dev/null 2>&1 || return 1

  # Look for any non-CPU device
  DISPLAY= vulkaninfo --summary 2>/dev/null |
    grep -qE 'PHYSICAL_DEVICE_TYPE_(INTEGRATED_GPU|DISCRETE_GPU|VIRTUAL_GPU)'
}

sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences

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
    echo "Starting Brave with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /opt/brave.com/brave/brave-browser ${CHROME_ARGS} \${VULKAN_FLAGS} \${EXTENSION_FLAGS} "\$@"
else
    echo "Starting Brave"
    /opt/brave.com/brave/brave-browser ${CHROME_ARGS} \${VULKAN_FLAGS} \${EXTENSION_FLAGS} "\$@"
fi
EOL
chmod +x /usr/bin/brave-browser
cp /usr/bin/brave-browser /usr/bin/brave

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


sed -i 's@exec -a "$0" "$HERE/brave-browser" "$\@"@@g' /usr/bin/x-www-browser
cat >>/usr/bin/x-www-browser <<EOL
exec -a "\$0" "\$HERE/brave" "${CHROME_ARGS}"  "\$@"
EOL

mkdir -p /etc/opt/chrome/policies/
mkdir -p /etc/brave
ln -s /etc/opt/chrome/policies /etc/brave/policies
mkdir -p /etc/brave/policies/managed/ 
cat >>/etc/brave/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL
cat >>/etc/brave/policies/managed/disable_tor.json <<EOL
{"TorDisabled": true}
EOL

# Cleanup
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;

DEVICE_EXTENSION_POLICY_DIR=/etc/brave/policies/managed \
  register_device_extension /usr/share/brave/extensions /opt/brave.com/brave/extensions
