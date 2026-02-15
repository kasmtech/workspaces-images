#!/usr/bin/env bash
set -ex

# Tell pnpm/node we're in a non-interactive CI environment (no TTY)
export CI=true

# Install dependencies including python3 (for gateway launcher) and Node.js 22
apt-get update
apt-get install -y python3 python3-pip git curl

# Download and install Node.js 22
NODESOURCE_SCRIPT=$(mktemp)
curl -fsSL https://deb.nodesource.com/setup_22.x -o "$NODESOURCE_SCRIPT" || { echo "Failed to download Node.js setup script"; exit 1; }
bash "$NODESOURCE_SCRIPT"
rm -f "$NODESOURCE_SCRIPT"
apt-get install -y nodejs

# Enable corepack for pnpm
corepack enable
corepack prepare pnpm@latest --activate

# Clone CareerClaw (OpenClaw fork)
CAREERCLAW_DIR="/opt/careerclaw"
if [ -d "$CAREERCLAW_DIR" ]; then
    rm -rf "$CAREERCLAW_DIR"
fi

echo "Cloning CareerClaw repository..."
git clone --depth 1 https://github.com/alexander-acker/careerclaw.git "$CAREERCLAW_DIR" || { echo "Failed to clone CareerClaw repo"; exit 1; }

# Build CareerClaw
cd "$CAREERCLAW_DIR"
echo "Installing dependencies..."
pnpm install --frozen-lockfile || { echo "Failed to install dependencies"; exit 1; }

echo "Building CareerClaw..."
pnpm build || { echo "Failed to build CareerClaw"; exit 1; }
pnpm ui:build || { echo "Failed to build UI"; exit 1; }

# Slim down: drop dev dependencies and git history to save ~300-500 MB
echo "Pruning development dependencies..."
CI=true pnpm prune --prod
rm -rf .git

# Create CLI wrapper so 'openclaw' is available system-wide
cat > /usr/local/bin/openclaw <<'WRAPPER'
#!/usr/bin/env bash
exec node /opt/careerclaw/openclaw.mjs "$@"
WRAPPER
chmod +x /usr/local/bin/openclaw

# Create gateway launcher script (used by autostart)
cat > /usr/local/bin/careerclaw-gateway <<'LAUNCHER'
#!/usr/bin/env bash
GATEWAY_LOG="$HOME/.openclaw/gateway.log"
mkdir -p "$HOME/.openclaw"
chmod 700 "$HOME/.openclaw"

# Don't start if already running
if ss -tlnp 2>/dev/null | grep -q ":18789"; then
    echo "CareerClaw gateway already running" >> "$GATEWAY_LOG"
    exit 0
fi

# Enforce localhost binding — overwrite config if tampered (defense-in-depth)
CONFIG="$HOME/.openclaw/openclaw.json"
if [ -f "$CONFIG" ]; then
    BIND_ADDR=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('gateway',{}).get('bind',''))" 2>/dev/null || echo "")
    if [ "$BIND_ADDR" != "loopback" ]; then
        echo "[$(date)] SECURITY: bind was '$BIND_ADDR', forcing to loopback" >> "$GATEWAY_LOG"
        python3 -c "
import json
c = json.load(open('$CONFIG'))
c.setdefault('gateway',{})['bind'] = 'loopback'
json.dump(c, open('$CONFIG','w'), indent=2)
" 2>/dev/null
    fi
fi

echo "[$(date)] Starting CareerClaw gateway..." >> "$GATEWAY_LOG"
exec /usr/local/bin/openclaw gateway >> "$GATEWAY_LOG" 2>&1
LAUNCHER
chmod +x /usr/local/bin/careerclaw-gateway

# Create default config directory for the Kasm default profile
OPENCLAW_STATE="$HOME/.openclaw"
mkdir -p "$OPENCLAW_STATE/workspace"
mkdir -p "$OPENCLAW_STATE/agents/main/sessions"
mkdir -p "$OPENCLAW_STATE/credentials"

# Generate a per-install gateway token
GATEWAY_TOKEN=$(openssl rand -hex 32)

cat > "$OPENCLAW_STATE/openclaw.json" <<CONF
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-sonnet-4-5-20250929"
      }
    }
  },
  "gateway": {
    "mode": "local",
    "port": 18789,
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "$GATEWAY_TOKEN"
    }
  }
}
CONF
chmod 600 "$OPENCLAW_STATE/openclaw.json"

# Save token separately so the Tauri launcher can read it
echo "$GATEWAY_TOKEN" > "$OPENCLAW_STATE/gateway-token"
chmod 600 "$OPENCLAW_STATE/gateway-token"

# Create desktop icon
mkdir -p /usr/share/icons/hicolor/apps
cp "$CAREERCLAW_DIR/assets/icon.png" /usr/share/icons/hicolor/apps/careerclaw.png 2>/dev/null || \
  wget -q -O /usr/share/icons/hicolor/apps/careerclaw.png \
    "https://raw.githubusercontent.com/alexander-acker/careerclaw/main/assets/icon.png" 2>/dev/null || \
  echo "No icon found, using default"

# Desktop shortcut to open the gateway web UI
cat > /usr/share/applications/careerclaw.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=CareerClaw AI
Comment=AI Career Assistant - OpenClaw Gateway
Exec=xdg-open http://localhost:18789
Icon=/usr/share/icons/hicolor/apps/careerclaw.png
Terminal=false
Categories=Utility;Network;
StartupNotify=true
DESKTOP

cp /usr/share/applications/careerclaw.desktop "$HOME/Desktop/"
chmod +x "$HOME/Desktop/careerclaw.desktop"
chown 1000:1000 "$HOME/Desktop/careerclaw.desktop"

# XFCE autostart: launch gateway automatically at desktop login
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/careerclaw-gateway.desktop <<'AUTOSTART'
[Desktop Entry]
Type=Application
Name=CareerClaw Gateway
Comment=Start CareerClaw AI gateway in background
Exec=/usr/local/bin/careerclaw-gateway
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
AUTOSTART

# Set ownership
chown -R 1000:0 "$CAREERCLAW_DIR"
chown -R 1000:0 "$OPENCLAW_STATE"

# Ensure VNC startup script is correct (fix for grey screen issue)
mkdir -p "/home/kasm-user/.vnc"
cat > "/home/kasm-user/.vnc/xstartup" <<'XSTARTUP'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
XSTARTUP
chmod +x "/home/kasm-user/.vnc/xstartup"
chown 1000:0 "/home/kasm-user/.vnc/xstartup"

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;

if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi
