#!/usr/bin/env bash
set -ex

TRAE_DEB_URL="https://lf-cdn.trae.ai/obj/trae-ai-sg/pkg/app/releases/stable/2.3.29372/linux/Trae-linux-x64.deb"

apt-get update
# apt-get install -y ca-certificates wget
wget -q "${TRAE_DEB_URL}" -O trae_ai.deb
apt-get install -y python3-setuptools python3-venv python3-virtualenv \
                   ca-certificates wget \
                   ./trae_ai.deb

cat >/usr/local/bin/trae-ai <<'EOF'
#!/usr/bin/env bash
set -e

for candidate in \
  "/usr/bin/trae-ai" \
  "/usr/bin/trae" \
  "/usr/share/trae-ai/trae-ai" \
  "/usr/share/trae-ai/trae" \
  "/usr/share/trae/trae" \
  "/opt/Trae AI/trae-ai" \
  "/opt/Trae AI/trae" \
  "/opt/Trae/trae"
do
  if [ -x "$candidate" ]; then
    exec "$candidate" --no-sandbox "$@"
  fi
done

FOUND=$(find /usr/bin /usr/share /opt -maxdepth 4 -type f -perm -111 \( -iname 'trae' -o -iname 'trae-ai' \) 2>/dev/null | head -n 1)
if [ -n "$FOUND" ]; then
  exec "$FOUND" --no-sandbox "$@"
fi

echo "Unable to find the Trae AI executable." >&2
exit 1
EOF
chmod +x /usr/local/bin/trae-ai

mkdir -p "$HOME/Desktop"
DESKTOP_FILE=$(find /usr/share/applications -maxdepth 1 -type f -iname '*trae*.desktop' | head -n 1)
if [ -n "$DESKTOP_FILE" ]; then
  sed -i 's#^Exec=.*#Exec=/usr/local/bin/trae-ai %U#' "$DESKTOP_FILE"
  cp "$DESKTOP_FILE" "$HOME/Desktop/trae-ai.desktop"
else
  cat >"$HOME/Desktop/trae-ai.desktop" <<'EOF'
[Desktop Entry]
Name=Trae AI
Comment=AI coding agent
Exec=/usr/local/bin/trae-ai %U
Terminal=false
Type=Application
Icon=trae-ai
StartupNotify=true
Categories=Development;IDE;
EOF
fi
chmod +x "$HOME/Desktop/trae-ai.desktop"
chown 1000:1000 "$HOME/Desktop/trae-ai.desktop"
rm trae_ai.deb

# apt-get update
# apt-get install -y python3-setuptools \
#                    python3-venv \
#                    python3-virtualenv

chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi