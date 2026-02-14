#!/usr/bin/env bash
set -ex

# Install Node.js 22 (required by OpenClaw/CareerClaw)
# Download setup script first, then execute — avoids pipe-to-bash risks
NODESOURCE_SCRIPT=$(mktemp)
curl -fsSL https://deb.nodesource.com/setup_22.x -o "$NODESOURCE_SCRIPT"
bash "$NODESOURCE_SCRIPT"
rm -f "$NODESOURCE_SCRIPT"
apt-get install -y nodejs git

# Enable corepack for pnpm
corepack enable
corepack prepare pnpm@latest --activate

# Clone CareerClaw (OpenClaw fork)
CAREERCLAW_DIR="/opt/careerclaw"
git clone --depth 1 https://github.com/alexander-acker/careerclaw.git "$CAREERCLAW_DIR"

# Build CareerClaw
cd "$CAREERCLAW_DIR"
pnpm install --frozen-lockfile
pnpm build
pnpm ui:build

# Slim down: drop dev dependencies and git history to save ~300-500 MB
pnpm prune --prod
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

# Verify gateway is bound to localhost only (defense-in-depth)
BIND_ADDR=$(python3 -c "import json; print(json.load(open('$HOME/.openclaw/openclaw.json')).get('gateway',{}).get('bind',''))" 2>/dev/null || echo "")
if [ "$BIND_ADDR" != "127.0.0.1" ]; then
    echo "[$(date)] SECURITY: Refusing to start — gateway must bind to 127.0.0.1" >> "$GATEWAY_LOG"
    exit 1
fi

echo "[$(date)] Starting CareerClaw gateway..." >> "$GATEWAY_LOG"
exec /usr/local/bin/openclaw gateway >> "$GATEWAY_LOG" 2>&1
LAUNCHER
chmod +x /usr/local/bin/careerclaw-gateway

# Create default config directory for the Kasm default profile
OPENCLAW_STATE="$HOME/.openclaw"
mkdir -p "$OPENCLAW_STATE/workspace"

cat > "$OPENCLAW_STATE/openclaw.json" <<'CONF'
{
  "agent": {
    "model": "anthropic/claude-sonnet-4-5-20250929"
  },
  "gateway": {
    "port": 18789,
    "bind": "127.0.0.1",
    "cors": {
      "allowedOrigins": ["http://localhost:18789", "http://127.0.0.1:18789"]
    }
  }
}
CONF
chmod 600 "$OPENCLAW_STATE/openclaw.json"

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
