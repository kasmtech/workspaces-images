#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

apt-get update
apt-get install -y jq

if [ "$ARCH" != "amd64" ]; then
  apt-get install -y zlib1g-dev libfuse2
fi

# Some GitHub releases (e.g. mobile-only point releases) don't ship a Linux
# AppImage asset, so walk releases newest-first until one has a matching asset.
if [ "$ARCH" == "amd64" ]; then
  ASSET_FILTER='select(.name | test("AppImage$") and (contains("arm64") | not))'
else
  ASSET_FILTER='select(.name | test("arm64") and test("AppImage$"))'
fi

DOWNLOAD_URL=""
for PAGE in 1 2; do
  RELEASES_JSON=$(curl -s "https://api.github.com/repos/obsidianmd/obsidian-releases/releases?per_page=30&page=${PAGE}")
  DOWNLOAD_URL=$(echo "$RELEASES_JSON" | jq -r "[.[] | select(.draft == false and .prerelease == false) | .assets[] | $ASSET_FILTER | .browser_download_url] | first // empty")
  if [ -n "$DOWNLOAD_URL" ]; then
    break
  fi
done

if [ -z "$DOWNLOAD_URL" ]; then
  echo "ERROR: could not find an Obsidian AppImage download URL for arch $ARCH" >&2
  exit 1
fi

# Download App Image
mkdir -p /opt/Obsidian
cd /opt/Obsidian
wget -q "$DOWNLOAD_URL" -O Obsidian.AppImage
chmod +x Obsidian.AppImage

# Extract and create launcher
./Obsidian.AppImage --appimage-extract
rm Obsidian.AppImage
chown -R 1000:1000 /opt/Obsidian

cat >/opt/Obsidian/squashfs-root/launcher <<EOL
#!/usr/bin/env bash
export APPDIR=/opt/Obsidian/squashfs-root
/opt/Obsidian/squashfs-root/AppRun --no-sandbox "$@"
EOL
chmod +x /opt/Obsidian/squashfs-root/launcher

# Find and update the desktop file
DESKTOP_FILE=$(find /opt/Obsidian/squashfs-root -name "obsidian.desktop" | head -1)
if [ -f "$DESKTOP_FILE" ]; then
  sed -i 's@^Exec=.*@Exec=/opt/Obsidian/squashfs-root/launcher@g' "$DESKTOP_FILE"
  sed -i 's@^Icon=.*@Icon=/opt/Obsidian/squashfs-root/obsidian.png@g' "$DESKTOP_FILE"
  cp "$DESKTOP_FILE" $HOME/Desktop
  cp "$DESKTOP_FILE" /usr/share/applications/
  chmod +x $HOME/Desktop/obsidian.desktop
  chmod +x /usr/share/applications/obsidian.desktop
fi