#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

apt-get update
apt-get install -y jq

# Use GitHub API to get latest stable release of Obsidian
LATEST_RELEASE=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | jq -r .tag_name)

# Use GitHub API to get download URL for amd64
if [ "$ARCH" == "amd64" ]; then
  DOWNLOAD_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | jq -r '.assets[] | select(.name | test("AppImage$") and (contains("arm64") | not)) | .browser_download_url')
else
  apt-get install -y zlib1g-dev libfuse2
  DOWNLOAD_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | jq -r '.assets[] | select(.name | test("arm64") and test("AppImage$")) | .browser_download_url')
fi

# Download App Image
mkdir -p /opt/Obsidian
cd /opt/Obsidian
wget -q $DOWNLOAD_URL -O Obsidian.AppImage
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

sed -i 's@^Exec=.*@Exec=/opt/Obsidian/squashfs-root/launcher@g' /opt/Obsidian/squashfs-root/obsidian.desktop
sed -i 's@^Icon=.*@Icon=/opt/Obsidian/squashfs-root/obsidian.png@g' /opt/Obsidian/squashfs-root/obsidian.desktop
cp /opt/Obsidian/squashfs-root/obsidian.desktop  $HOME/Desktop
cp /opt/Obsidian/squashfs-root/obsidian.desktop /usr/share/applications/
chmod +x $HOME/Desktop/obsidian.desktop
chmod +x /usr/share/applications/obsidian.desktop