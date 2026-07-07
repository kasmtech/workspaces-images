#!/usr/bin/env bash
#
# Post-install remediation for the Trace Labs OSINT tools script
# on debian:13 (trixie) image.
#
# It fixes the validator failures the tlosint script leaves behind:
#   1. sn0int            - apt.vulns.xyz repo key is out of sync with Debian 13's
#                          sqv verifier, so the apt install fails. We build sn0int
#                          from source into /usr/local/bin (on PATH for every user).
#   2. metagoofil        - not packaged for Debian and not pip-installable from the
#                          opsdisk repo; we install it as a script + launcher shim.
#   3. torbrowser-launcher - lives in the `contrib` component, not enabled by default.
#   4. participant-guide.desktop - the upstream script never creates this file.
#
#
set -euo pipefail

log()  { printf '[fix-tlosint] %s\n' "$*"; }
warn() { printf '[fix-tlosint][WARN] %s\n' "$*" >&2; }

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
  TARGET_USER="${SUDO_USER:-root}"
else
  if ! command -v sudo >/dev/null 2>&1; then
    echo "Not root and 'sudo' is not installed; cannot perform privileged steps." >&2
    exit 1
  fi
  SUDO="sudo"
  TARGET_USER="$(id -un)"
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-/root}"
log "Privileged ops via '${SUDO:-<root>}'; desktop target: ${TARGET_USER} (${TARGET_HOME})"

export DEBIAN_FRONTEND=noninteractive

enable_contrib() {
  local src="/etc/apt/sources.list.d/debian.sources"
  if [ -f "$src" ]; then
    # deb822 format (Debian 13 default)
    if ! grep -qE '^Components:.*\bcontrib\b' "$src"; then
      log "Enabling 'contrib' component in $src"
      $SUDO sed -i -E 's/^(Components:.*)$/\1 contrib/' "$src"
    else
      log "'contrib' already enabled in $src"
    fi
  else
    # legacy one-line format
    log "Enabling 'contrib' in /etc/apt/sources.list (legacy format)"
    $SUDO sed -i -E '/^deb .* main( |$)/ { /contrib/! s/ main/ main contrib/ }' /etc/apt/sources.list || true
  fi
}

enable_contrib
$SUDO apt-get update -y || warn "apt-get update reported errors (e.g. the broken vulns.xyz repo) - continuing"

if ! command -v torbrowser-launcher >/dev/null 2>&1; then
  log "Installing torbrowser-launcher"
  $SUDO apt-get install -y torbrowser-launcher
else
  log "torbrowser-launcher already present"
fi

# Reuse an existing build if the upstream cargo fallback already produced one
  # (e.g. ~/.cargo/bin/sn0int); otherwise build from source.
if [ ! -x /usr/local/bin/sn0int ]; then
  existing_sn0int="$(command -v sn0int 2>/dev/null || true)"
  if [ -n "$existing_sn0int" ]; then
    log "Copying existing sn0int ($existing_sn0int) -> /usr/local/bin"
    $SUDO install -m 0755 "$existing_sn0int" /usr/local/bin/sn0int
  else
    log "Installing build dependencies for sn0int"
    $SUDO apt-get install -y cargo pkg-config libsqlite3-dev libseccomp-dev libsodium-dev libssl-dev
    log "Building sn0int from source (this can take several minutes)"
    CARGO_TMP="$(mktemp -d)"
    $SUDO env CARGO_HOME="$CARGO_TMP" cargo install --locked sn0int --root /usr/local
    $SUDO rm -rf "$CARGO_TMP"
  fi
else
  log "sn0int already present at /usr/local/bin/sn0int"
fi

if [ ! -x /usr/local/bin/metagoofil ]; then
  log "Installing metagoofil into an isolated venv"
  $SUDO apt-get install -y python3-venv git
  if [ ! -d /opt/metagoofil/.git ]; then
    $SUDO rm -rf /opt/metagoofil
    $SUDO git clone --depth 1 https://github.com/opsdisk/metagoofil.git /opt/metagoofil
  fi
  $SUDO python3 -m venv /opt/metagoofil/venv
  $SUDO /opt/metagoofil/venv/bin/pip install --upgrade pip
  if [ -f /opt/metagoofil/requirements.txt ]; then
    $SUDO /opt/metagoofil/venv/bin/pip install -r /opt/metagoofil/requirements.txt
  fi
  printf '#!/bin/sh\nexec /opt/metagoofil/venv/bin/python /opt/metagoofil/metagoofil.py "$@"\n' \
    | $SUDO tee /usr/local/bin/metagoofil >/dev/null
  $SUDO chmod +x /usr/local/bin/metagoofil
else
  log "metagoofil already present at /usr/local/bin/metagoofil"
fi

DESKTOP_FILE="${TARGET_HOME}/Desktop/participant-guide.desktop"
if [ ! -f "$DESKTOP_FILE" ]; then
  log "Creating $DESKTOP_FILE"
  $SUDO mkdir -p "${TARGET_HOME}/Desktop"
  printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Link' \
    'Name=Trace Labs Participant Guide' \
    'Icon=text-html' \
    'URL=https://www.tracelabs.org/initiatives/search-party' \
    | $SUDO tee "$DESKTOP_FILE" >/dev/null
  $SUDO chmod +x "$DESKTOP_FILE"
  $SUDO chown "$TARGET_USER:" "${TARGET_HOME}/Desktop" "$DESKTOP_FILE" 2>/dev/null || true
else
  log "$DESKTOP_FILE already exists"
fi

# Chromium-based browsers crash silently inside Docker because kernel-namespace
# sandboxing is unavailable. Wrap each binary to inject --no-sandbox
BRAVE_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --check-for-update-interval=31449600"

if command -v brave-browser >/dev/null 2>&1 && [ ! -x /usr/bin/brave-browser-stable-orig ]; then
    log "Wrapping brave-browser-stable with --no-sandbox"
    $SUDO mv /usr/bin/brave-browser-stable /usr/bin/brave-browser-stable-orig
    $SUDO tee /usr/bin/brave-browser-stable >/dev/null <<BRAVE_WRAPPER
#!/usr/bin/env bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "\$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences" 2>/dev/null || true
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' "\$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences" 2>/dev/null || true
exec /opt/brave.com/brave/brave-browser $BRAVE_ARGS "\$@"
BRAVE_WRAPPER
    $SUDO chmod +x /usr/bin/brave-browser-stable
    $SUDO ln -sf /usr/bin/brave-browser-stable /usr/bin/brave-browser
else
    log "brave-browser wrapper already in place or brave not installed"
fi

# Debian's packaged Chromium (149.x) crashes with SIGTRAP in this container/kernel
# environment. Replace it with Google Chrome.
CHROME_FLAGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --disable-search-engine-choice-screen"
CHROME_ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "$CHROME_ARCH" = "arm64" ]; then
    log "arm64: skipping Chromium→Chrome replacement (Google Chrome unavailable on arm64)"
elif ! command -v google-chrome >/dev/null 2>&1; then
    log "Replacing Debian chromium (SIGTRAP crash) with Google Chrome"
    $SUDO apt-get purge -y chromium chromium-common chromium-sandbox 2>/dev/null || true
    $SUDO wget -q -O /tmp/google-chrome-stable.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    $SUDO apt-get install -y /tmp/google-chrome-stable.deb
    $SUDO rm -f /tmp/google-chrome-stable.deb
    $SUDO mv /usr/bin/google-chrome /usr/bin/google-chrome-orig
    $SUDO tee /usr/bin/google-chrome >/dev/null <<CHROME_WRAPPER
#!/usr/bin/env bash
if ! pgrep chrome > /dev/null; then
    rm -f "\$HOME/.config/google-chrome/Singleton"*
fi
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "\$HOME/.config/google-chrome/Default/Preferences" 2>/dev/null || true
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' "\$HOME/.config/google-chrome/Default/Preferences" 2>/dev/null || true
exec /opt/google/chrome/google-chrome $CHROME_FLAGS "\$@"
CHROME_WRAPPER
    $SUDO chmod +x /usr/bin/google-chrome
    $SUDO cp /usr/bin/google-chrome /usr/bin/chrome
    $SUDO ln -sf /usr/bin/google-chrome /usr/bin/chromium
    $SUDO sed -i 's/-stable//g' /usr/share/applications/google-chrome.desktop 2>/dev/null || true
    $SUDO mkdir -p /etc/opt/chrome/policies/managed/
    printf '%s\n' '{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false, "PrivacySandboxPromptEnabled": false}' \
        | $SUDO tee /etc/opt/chrome/policies/managed/default_managed_policy.json >/dev/null
else
    log "Google Chrome already installed, skipping Chromium replacement"
fi

log "Done. Re-run the validator, or check:  sn0int -V ; metagoofil -h ; torbrowser-launcher --help"
