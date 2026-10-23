#!/usr/bin/env bash
set -ex

VIVALDI_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"

# Install Vivaldi (Ubuntu)
wget -qO- https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor > /usr/share/keyrings/vivaldi-browser.gpg
echo "deb [signed-by=/usr/share/keyrings/vivaldi-browser.gpg arch=$(dpkg --print-architecture)] https://repo.vivaldi.com/archive/deb/ stable main" > /etc/apt/sources.list.d/vivaldi-archive.list
apt-get update && apt-get install -y vivaldi-stable
mkdir -p /var/opt/vivaldi
set +e
for i in {1..120}; do
    /opt/vivaldi/update-ffmpeg
    if [ $? -eq 0 ]; then
        break
    fi
    sleep 1
done
set -e

# Add Desktop Icon
cp /usr/share/applications/vivaldi-stable.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/vivaldi-stable.desktop
chmod +x $HOME/Desktop/vivaldi-stable.desktop

# Use wrapper to launch application
mv /opt/vivaldi/vivaldi /opt/vivaldi/vivaldi-orig
cat >/opt/vivaldi/vivaldi <<EOL
#!/usr/bin/env bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/vivaldi/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/vivaldi/Default/Preferences

DEVICE_EXTENSION_DIR="/dockerstartup/device_extension/workspace-device-extension"
DEVICE_EXTENSION_CRX="\${DEVICE_EXTENSION_DIR}.crx"
EXTENSION_FLAGS=
# A packed CRX is registered as an external extension at build time, only fall back to
#   loading the unpacked extension when the browser build still allows it.
if [ ! -f "\${DEVICE_EXTENSION_CRX}" ] && [ -d "\${DEVICE_EXTENSION_DIR}" ]; then
  EXTENSION_FLAGS="--load-extension=\${DEVICE_EXTENSION_DIR}"
fi

if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Vivaldi with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /opt/vivaldi/vivaldi-orig ${CHROME_ARGS} \${EXTENSION_FLAGS} "\$@"
else
    echo "Starting Vivaldi"
    /opt/vivaldi/vivaldi-orig ${VIVALDI_ARGS} \${EXTENSION_FLAGS} "\$@"
fi
EOL
chmod +x /opt/vivaldi/vivaldi

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


# Set mime type to launch web content
sed -i 's@exec -a "$0" "$HERE/vivaldi" "$\@"@@g' /usr/bin/x-www-browser
cat >>/usr/bin/x-www-browser <<EOL
  exec -a "\$0" "\$HERE/vivaldi" "${VIVALDI_ARGS}"  "\$@"
EOL

# Set chrome managed policies for vivaldi
mkdir -p /etc/opt/chrome/policies/managed/
cat >>/etc/opt/chrome/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
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

DEVICE_EXTENSION_POLICY_DIR=/etc/opt/vivaldi/policies/managed \
  register_device_extension /usr/share/vivaldi/extensions /opt/vivaldi/extensions
