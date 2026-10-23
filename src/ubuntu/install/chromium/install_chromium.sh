#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox  --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [[ "${DISTRO}" == @(debian|opensuse|ubuntu) ]] && [ ${ARCH} = 'amd64' ] && [ ! -z ${SKIP_CLEAN+x} ]; then
  echo "not installing chromium on x86_64 desktop build"
  exit 0
fi

if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|rhel9|almalinux9|almalinux8|fedora42|fedora43) ]]; then
  dnf install -y chromium
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
elif [ "${DISTRO}" == "opensuse" ]; then
  zypper install -yn chromium
  if [ -z ${SKIP_CLEAN+x} ]; then
    zypper clean --all
  fi
elif grep -q "ID=debian" /etc/os-release || grep -q "ID=kali" /etc/os-release || grep -q "ID=parrot" /etc/os-release; then
  apt-get update
  apt-get install -y chromium
  if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
  fi
else
  apt-get update
  apt-get install -y software-properties-common ttf-mscorefonts-installer
  apt-get remove -y chromium-browser-l10n chromium-codecs-ffmpeg chromium-browser

  # Install from debian bookworm repos
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://ftp-master.debian.org/keys/archive-key-12.asc | sudo tee /etc/apt/keyrings/debian-archive-key-12.asc
  echo "deb [signed-by=/etc/apt/keyrings/debian-archive-key-12.asc] http://deb.debian.org/debian bookworm main" | sudo tee /etc/apt/sources.list.d/debian-bookworm.list
  echo -e "Package: *\nPin: release a=bookworm\nPin-Priority: 100" | sudo tee /etc/apt/preferences.d/debian-bookworm
  apt-get update
  apt install -y chromium --no-install-recommends

  # Cleanup debian bookworm repos
  rm /etc/apt/sources.list.d/debian-bookworm.list
  rm /etc/apt/preferences.d/debian-bookworm
  rm /etc/apt/keyrings/debian-archive-key-12.asc
  apt-get update

  if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
  fi

fi

if grep -q "ID=debian" /etc/os-release || grep -q "ID=kali" /etc/os-release || grep -q "ID=parrot" /etc/os-release || grep -q "ID=ubuntu" /etc/os-release; then
  REAL_BIN=chromium
else
  REAL_BIN=chromium-browser
fi


sed -i 's/-stable//g' /usr/share/applications/${REAL_BIN}.desktop

if ! grep -q "ID=kali" /etc/os-release; then
  cp /usr/share/applications/${REAL_BIN}.desktop $HOME/Desktop/
  chmod +x $HOME/Desktop/${REAL_BIN}.desktop
  chown 1000:1000 $HOME/Desktop/${REAL_BIN}.desktop
fi

mv /usr/bin/${REAL_BIN} /usr/bin/${REAL_BIN}-orig
cat >/usr/bin/${REAL_BIN} <<EOL
#!/usr/bin/env bash

supports_vulkan() {
  # Needs the CLI tool
  command -v vulkaninfo >/dev/null 2>&1 || return 1

  # Look for any non-CPU device
  DISPLAY= vulkaninfo --summary 2>/dev/null |
    grep -qE 'PHYSICAL_DEVICE_TYPE_(INTEGRATED_GPU|DISCRETE_GPU|VIRTUAL_GPU)'
}

if ! pgrep chromium > /dev/null;then
  rm -f \$HOME/.config/chromium/Singleton*
fi
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/chromium/Default/Preferences

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
    echo "Starting Chrome with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /usr/bin/${REAL_BIN}-orig ${CHROME_ARGS} \${VULKAN_FLAGS} \${EXTENSION_FLAGS} "\$@"
else
    echo "Starting Chrome"
    /usr/bin/${REAL_BIN}-orig ${CHROME_ARGS} \${VULKAN_FLAGS} \${EXTENSION_FLAGS} "\$@"
fi
EOL
chmod +x /usr/bin/${REAL_BIN}

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


if [ "${DISTRO}" != "opensuse" ] && ! grep -q "ID=debian" /etc/os-release && ! grep -q "ID=kali" /etc/os-release && ! grep -q "ID=parrot" /etc/os-release && ! grep -q "ID=ubuntu" /etc/os-release; then
  cp /usr/bin/chromium-browser /usr/bin/chromium
fi

if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|rhel9|almalinux9|almalinux8|opensuse|fedora42|fedora43) ]]; then
  cat >> $HOME/.config/mimeapps.list <<EOF
    [Default Applications]
    x-scheme-handler/http=${REAL_BIN}.desktop
    x-scheme-handler/https=${REAL_BIN}.desktop
    x-scheme-handler/ftp=${REAL_BIN}.desktop
    x-scheme-handler/chrome=${REAL_BIN}.desktop
    text/html=${REAL_BIN}.desktop
    application/x-extension-htm=${REAL_BIN}.desktop
    application/x-extension-html=${REAL_BIN}.desktop
    application/x-extension-shtml=${REAL_BIN}.desktop
    application/xhtml+xml=${REAL_BIN}.desktop
    application/x-extension-xhtml=${REAL_BIN}.desktop
    application/x-extension-xht=${REAL_BIN}.desktop
EOF
else
  sed -i 's@exec -a "$0" "$HERE/chromium-browser" "$\@"@@g' /usr/bin/x-www-browser
  cat >>/usr/bin/x-www-browser <<EOL
  exec -a "\$0" "\$HERE/chromium" "${CHROME_ARGS}"  "\$@"
EOL
fi

mkdir -p /etc/chromium/policies/managed/
cat >>/etc/chromium/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL

patch_debian_extension_hook() {
  DEBIAN_EXTENSION_HOOK=/etc/chromium.d/extensions

  if [ ! -f "${DEBIAN_EXTENSION_HOOK}" ]; then
    return 0
  fi

  cat >"${DEBIAN_EXTENSION_HOOK}" <<'EOF'
# remote extensions on by default
export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --enable-remote-extensions"

# Load the unpacked extensions installed to /usr/share/chromium/extensions. Only
#   directories are extensions: the *.json files there are external extension prefs,
#   which chromium reads on its own and which --load-extension cannot load.
KASM_CHROMIUM_EXTENSIONS=
for KASM_CHROMIUM_EXTENSION in /usr/share/chromium/extensions/*/; do
  [ -d "${KASM_CHROMIUM_EXTENSION}" ] || continue
  KASM_CHROMIUM_EXTENSION="${KASM_CHROMIUM_EXTENSION%/}"
  if [ -z "${KASM_CHROMIUM_EXTENSIONS}" ]; then
    KASM_CHROMIUM_EXTENSIONS="${KASM_CHROMIUM_EXTENSION}"
  else
    KASM_CHROMIUM_EXTENSIONS="${KASM_CHROMIUM_EXTENSIONS},${KASM_CHROMIUM_EXTENSION}"
  fi
done

# An empty --load-extension= is an error in itself, so only pass the flag when there
#   is something to load.
if [ -n "${KASM_CHROMIUM_EXTENSIONS}" ]; then
  export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --load-extension=${KASM_CHROMIUM_EXTENSIONS}"
fi
EOF

  echo "Patched ${DEBIAN_EXTENSION_HOOK} to skip external extension prefs"
}

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;

patch_debian_extension_hook

DEVICE_EXTENSION_POLICY_DIR=/etc/chromium/policies/managed \
  register_device_extension /usr/share/chromium/extensions /usr/share/chromium-browser/extensions
