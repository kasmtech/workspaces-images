#!/usr/bin/env bash
set -ex

# ---------------------------------------------------------------------------
# Install the Coeadapt VM Agent Services
#
# Two lightweight Python services that run inside the Kasm workspace container:
#   1. Progress Tracker  (port 7700) — career progress persistence & API
#   2. Computer-Use      (port 7701) — mouse, keyboard, screen control
#
# Both bind to 127.0.0.1 only (defense-in-depth: not reachable from outside).
# The MCP server on the host reaches them via `docker exec`.
# ---------------------------------------------------------------------------

AGENT_DIR="/opt/coeadapt-agent"
STATE_DIR="/home/kasm-user/.coeadapt"

# --- System dependencies ---
apt-get update
apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    xdotool \
    imagemagick \
    x11-utils

# --- Install agent code ---
mkdir -p "$AGENT_DIR"
cp -r "$(dirname "$0")/agent/"*.py "$AGENT_DIR/"
chmod 644 "$AGENT_DIR"/*.py

# --- Create state directory ---
mkdir -p "$STATE_DIR"

# Initialize progress.json if it doesn't exist
if [ ! -f "$STATE_DIR/progress.json" ]; then
    cat > "$STATE_DIR/progress.json" <<'JSON'
{
  "version": 1,
  "activities": [],
  "assessments": [],
  "goals": [],
  "skills": [],
  "milestones": [],
  "daily_log": [],
  "progress_percent": 0,
  "streak_days": 0,
  "last_activity_at": null,
  "created_at": null,
  "updated_at": null
}
JSON
fi

# --- Systemd-style launcher (runs as kasm-user) ---
cat > /usr/local/bin/coeadapt-agent <<'LAUNCHER'
#!/usr/bin/env bash
# Start both agent services in the background
AGENT_DIR="/opt/coeadapt-agent"
LOG_DIR="$HOME/.coeadapt/logs"
mkdir -p "$LOG_DIR"

# Don't start if already running
if ss -tlnp 2>/dev/null | grep -q ":7700"; then
    echo "Progress tracker already running"
else
    echo "[$(date)] Starting progress tracker..." >> "$LOG_DIR/progress.log"
    DISPLAY=${DISPLAY:-:1} python3 "$AGENT_DIR/progress_tracker.py" >> "$LOG_DIR/progress.log" 2>&1 &
fi

if ss -tlnp 2>/dev/null | grep -q ":7701"; then
    echo "Computer-use service already running"
else
    echo "[$(date)] Starting computer-use service..." >> "$LOG_DIR/computer_use.log"
    DISPLAY=${DISPLAY:-:1} python3 "$AGENT_DIR/computer_use.py" >> "$LOG_DIR/computer_use.log" 2>&1 &
fi

echo "Coeadapt agent services started"
LAUNCHER
chmod +x /usr/local/bin/coeadapt-agent

# --- Stop script ---
cat > /usr/local/bin/coeadapt-agent-stop <<'STOP'
#!/usr/bin/env bash
# Gracefully stop agent services
pkill -f "progress_tracker.py" 2>/dev/null || true
pkill -f "computer_use.py" 2>/dev/null || true
echo "Coeadapt agent services stopped"
STOP
chmod +x /usr/local/bin/coeadapt-agent-stop

# --- Health check script ---
cat > /usr/local/bin/coeadapt-agent-health <<'HEALTH'
#!/usr/bin/env bash
# Check health of both services
progress=$(curl -sf http://127.0.0.1:7700/health 2>/dev/null && echo "ok" || echo "down")
computer=$(curl -sf http://127.0.0.1:7701/health 2>/dev/null && echo "ok" || echo "down")
echo "{\"progress_tracker\": \"$progress\", \"computer_use\": \"$computer\"}"
HEALTH
chmod +x /usr/local/bin/coeadapt-agent-health

# --- XFCE autostart entry ---
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/coeadapt-agent.desktop <<'AUTOSTART'
[Desktop Entry]
Type=Application
Name=Coeadapt Agent
Comment=Start Coeadapt progress tracker and computer-use services
Exec=/usr/local/bin/coeadapt-agent
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
AUTOSTART

# --- Set ownership ---
chown -R 1000:0 "$AGENT_DIR"
chown -R 1000:0 "$STATE_DIR"

# --- Cleanup ---
chown -R 1000:0 /home/kasm-user
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;

if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi
