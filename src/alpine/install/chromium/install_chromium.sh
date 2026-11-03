#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox  --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"

apk add --no-cache \
  chromium 

REAL_BIN=chromium

cp /usr/share/applications/chromium.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/chromium.desktop

mv /usr/bin/chromium-browser /usr/bin/chromium-browser-orig
cat >/usr/bin/chromium-browser <<EOL
#!/usr/bin/env bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/chromium/Default/Preferences
DEVICE_EXTENSION_DIR="/dockerstartup/device_extension/workspace-device-extension"
DEVICE_EXTENSION_CRX="\${DEVICE_EXTENSION_DIR}.crx"
EXTENSION_FLAGS=
# A packed CRX is registered as an external extension at build time, only fall back to
#   loading the unpacked extension when the browser build still allows it.
if [ ! -f "\${DEVICE_EXTENSION_CRX}" ] && [ -d "\${DEVICE_EXTENSION_DIR}" ]; then
  EXTENSION_FLAGS="--load-extension=\${DEVICE_EXTENSION_DIR}"
fi

echo "Starting Chrome"
/usr/bin/chromium-browser-orig ${CHROME_ARGS} \${EXTENSION_FLAGS} "\$@"
EOL
chmod +x /usr/bin/chromium-browser

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

DEVICE_EXTENSION_POLICY_DIR=/etc/chromium/policies/managed \
  register_device_extension /usr/share/chromium/extensions /usr/share/chromium-browser/extensions
