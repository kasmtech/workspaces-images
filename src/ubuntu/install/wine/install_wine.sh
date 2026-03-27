#!/usr/bin/env bash
set -ex

# ============================================================================
# Wine + Winetricks for Kasm Workspaces
# Supports Ubuntu Jammy (22.04) and Noble (24.04)
# Uses modern DEB822 .sources format (no deprecated apt-key)
# ============================================================================

UBUNTU_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
echo "Installing Wine on Ubuntu ${UBUNTU_CODENAME}"

# --------------------------------------------------------------------------
# 1. Enable 32-bit architecture (required for most Windows apps)
# --------------------------------------------------------------------------
dpkg --add-architecture i386

# --------------------------------------------------------------------------
# 2. Add WineHQ repository using modern signed-by method
# --------------------------------------------------------------------------
apt-get update
apt-get install -y software-properties-common wget

mkdir -pm755 /etc/apt/keyrings
wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key

# Download the official .sources file for this Ubuntu release
wget -NP /etc/apt/sources.list.d/ \
  "https://dl.winehq.org/wine-builds/ubuntu/dists/${UBUNTU_CODENAME}/winehq-${UBUNTU_CODENAME}.sources"

apt-get update

# --------------------------------------------------------------------------
# 3. Install Wine Stable + Winetricks
# --------------------------------------------------------------------------
apt-get install -y --install-recommends winehq-stable || \
  apt-get install -y --install-recommends winehq-devel

apt-get install -y winetricks

# --------------------------------------------------------------------------
# 4. Initialize Wine prefix and install core fonts
#    This avoids a slow first-run experience for users
# --------------------------------------------------------------------------
export WINEPREFIX="/home/kasm-default-profile/.wine"
export WINEDLLOVERRIDES="mscoree,mshtml="
export DISPLAY=:1

# Initialize the Wine prefix (silent, no GUI)
wineboot --init 2>/dev/null || true
sleep 2

# Install core Windows fonts via winetricks (improves app rendering)
winetricks -q corefonts 2>/dev/null || true

# --------------------------------------------------------------------------
# 5. Create .desktop file for Wine configuration
# --------------------------------------------------------------------------
mkdir -p /home/kasm-default-profile/Desktop
cat > /home/kasm-default-profile/Desktop/wine-config.desktop << 'DEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine Configuration
Comment=Configure Wine Windows Compatibility
Exec=winecfg
Icon=wine
Terminal=false
Categories=System;
DEOF
chmod +x /home/kasm-default-profile/Desktop/wine-config.desktop

# --------------------------------------------------------------------------
# 6. Set up .exe file association so double-clicking opens with Wine
# --------------------------------------------------------------------------
mkdir -p /home/kasm-default-profile/.local/share/applications
cat > /home/kasm-default-profile/.local/share/applications/wine.desktop << 'AEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine Windows Program Loader
MimeType=application/x-ms-dos-executable;application/x-msdos-program;application/x-executable;
Exec=wine %f
Icon=wine
Terminal=false
NoDisplay=true
AEOF

mkdir -p /home/kasm-default-profile/.local/share/mime/packages
cat > /home/kasm-default-profile/.local/share/mime/packages/wine.xml << 'MEOF'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-ms-dos-executable">
    <comment>Windows Executable</comment>
    <glob pattern="*.exe"/>
  </mime-type>
</mime-info>
MEOF

update-mime-database /home/kasm-default-profile/.local/share/mime 2>/dev/null || true

# --------------------------------------------------------------------------
# 7. Cleanup
# --------------------------------------------------------------------------
chown -R 1000:0 /home/kasm-default-profile

if [ -z "${SKIP_CLEAN+x}" ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi

echo "Wine installation complete: $(wine --version 2>/dev/null || echo 'version check failed')"
