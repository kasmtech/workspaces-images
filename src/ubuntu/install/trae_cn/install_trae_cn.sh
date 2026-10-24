#!/usr/bin/env bash
set -ex

TRAE_DEB_URL="https://lf-cdn.trae.com.cn/obj/trae-com-cn/pkg/app/releases/stable/2.3.27641/linux/Trae_CN-linux-x64.deb"

# Install Trae CN
apt-get update
apt-get install -y ca-certificates wget
wget -q "${TRAE_DEB_URL}" -O trae_cn.deb
apt-get install -y ./trae_cn.deb

# Provide a stable command name for startup scripts, regardless of the package's
# exact desktop entry or executable path.
cat >/usr/local/bin/trae-cn <<'EOF'
#!/usr/bin/env bash
set -e

for candidate in \
  "/usr/bin/trae-cn" \
  "/usr/bin/trae" \
  "/usr/share/trae-cn/trae-cn" \
  "/usr/share/trae-cn/trae" \
  "/usr/share/trae/trae" \
  "/opt/Trae CN/trae-cn" \
  "/opt/Trae CN/trae" \
  "/opt/Trae/trae"
do
  if [ -x "$candidate" ]; then
    exec "$candidate" --no-sandbox "$@"
  fi
done

FOUND=$(find /usr/bin /usr/share /opt -maxdepth 4 -type f -perm -111 \( -iname 'trae' -o -iname 'trae-cn' \) 2>/dev/null | head -n 1)
if [ -n "$FOUND" ]; then
  exec "$FOUND" --no-sandbox "$@"
fi

echo "Unable to find the Trae CN executable." >&2
exit 1
EOF
chmod +x /usr/local/bin/trae-cn

# Desktop icon
mkdir -p "$HOME/Desktop"
DESKTOP_FILE=$(find /usr/share/applications -maxdepth 1 -type f -iname '*trae*.desktop' | head -n 1)
if [ -n "$DESKTOP_FILE" ]; then
  sed -i 's#^Exec=.*#Exec=/usr/local/bin/trae-cn %U#' "$DESKTOP_FILE"
  cp "$DESKTOP_FILE" "$HOME/Desktop/trae-cn.desktop"
else
  cat >"$HOME/Desktop/trae-cn.desktop" <<'EOF'
[Desktop Entry]
Name=Trae CN
Comment=AI coding agent
Exec=/usr/local/bin/trae-cn %U
Terminal=false
Type=Application
Icon=trae-cn
StartupNotify=true
Categories=Development;IDE;
EOF
fi
chmod +x "$HOME/Desktop/trae-cn.desktop"
chown 1000:1000 "$HOME/Desktop/trae-cn.desktop"
rm trae_cn.deb

# Conveniences for python development
apt-get update
apt-get install -y python3-setuptools \
                   python3-venv \
                   python3-virtualenv

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
