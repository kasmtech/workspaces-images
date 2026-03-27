#!/usr/bin/env bash
set -ex

# ============================================================================
# Career-Box Desktop Theme — macOS-style
# Installs Colloid GTK/icon themes + Plank dock for a polished macOS layout
# on XFCE (Kasm Workspaces core-ubuntu-jammy / core-ubuntu-noble)
# ============================================================================

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

UBUNTU_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
echo "Detected Ubuntu: ${UBUNTU_CODENAME} (${ARCH})"

# --------------------------------------------------------------------------
# 1. Install dependencies
# --------------------------------------------------------------------------

apt-get update
apt-get install -y \
  git \
  sassc \
  gtk2-engines-murrine \
  gtk2-engines-pixbuf \
  gnome-themes-extra \
  plank \
  dconf-cli \
  unzip \
  wget

# --------------------------------------------------------------------------
# 2. Install Colloid GTK theme (dark variant)
# --------------------------------------------------------------------------

cd /tmp
git clone --depth 1 https://github.com/vinceliuice/Colloid-gtk-theme.git
cd Colloid-gtk-theme

# Install dark variant system-wide (to /usr/share/themes)
./install.sh -c dark -d /usr/share/themes

# Also install the xfwm4 window decorations
if [ -d "src/xfwm4" ]; then
  for theme_dir in /usr/share/themes/Colloid-Dark*/; do
    if [ -d "$theme_dir" ] && [ ! -d "${theme_dir}xfwm4" ]; then
      cp -r src/xfwm4/assets "${theme_dir}xfwm4" 2>/dev/null || true
    fi
  done
fi

cd /tmp && rm -rf Colloid-gtk-theme

# Verify installation
COLLOID_THEME="Colloid-Dark"
if [ ! -d "/usr/share/themes/${COLLOID_THEME}" ]; then
  # Fallback: try the exact name that was generated
  COLLOID_THEME=$(ls -d /usr/share/themes/Colloid*Dark* 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "Colloid-Dark")
  echo "Using theme: ${COLLOID_THEME}"
fi

# --------------------------------------------------------------------------
# 3. Install Colloid icon theme
# --------------------------------------------------------------------------

cd /tmp
git clone --depth 1 https://github.com/vinceliuice/Colloid-icon-theme.git
cd Colloid-icon-theme

# Install system-wide
./install.sh -d /usr/share/icons

cd /tmp && rm -rf Colloid-icon-theme

COLLOID_ICONS="Colloid-dark"
if [ ! -d "/usr/share/icons/${COLLOID_ICONS}" ]; then
  COLLOID_ICONS=$(ls -d /usr/share/icons/Colloid*dark* 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "Colloid-dark")
  echo "Using icons: ${COLLOID_ICONS}"
fi

# --------------------------------------------------------------------------
# 4. Set wallpaper
# --------------------------------------------------------------------------

# Use a dark gradient wallpaper — Kasm hardcodes bg_default.png
# Try Zorin wallpapers first (if PPA was previously installed), then fall back
WALLPAPER=""
for candidate in \
  /usr/share/backgrounds/Zorin-Dark.jpg \
  /usr/share/backgrounds/Zorin.jpg \
  /usr/share/backgrounds/bg_kasm.png; do
  if [ -f "${candidate}" ]; then
    WALLPAPER="${candidate}"
    break
  fi
done

if [ -n "${WALLPAPER}" ]; then
  cp "${WALLPAPER}" /usr/share/backgrounds/bg_default.png
  echo "Set wallpaper: ${WALLPAPER}"
else
  echo "Keeping default Kasm wallpaper"
fi

# --------------------------------------------------------------------------
# 5. Configure XFCE — Colloid Dark theme
# --------------------------------------------------------------------------

XFCE_CONF="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "${XFCE_CONF}"

# GTK theme + icon theme via xsettings
if [ -f "${XFCE_CONF}/xsettings.xml" ]; then
  sed -i "s|<property name=\"ThemeName\" type=\"empty\"/>|<property name=\"ThemeName\" type=\"string\" value=\"${COLLOID_THEME}\"/>|g" "${XFCE_CONF}/xsettings.xml"
  sed -i "s|<property name=\"ThemeName\" type=\"string\" value=\"[^\"]*\"/>|<property name=\"ThemeName\" type=\"string\" value=\"${COLLOID_THEME}\"/>|g" "${XFCE_CONF}/xsettings.xml"
  sed -i "s|<property name=\"IconThemeName\" type=\"empty\"/>|<property name=\"IconThemeName\" type=\"string\" value=\"${COLLOID_ICONS}\"/>|g" "${XFCE_CONF}/xsettings.xml"
  sed -i "s|<property name=\"IconThemeName\" type=\"string\" value=\"[^\"]*\"/>|<property name=\"IconThemeName\" type=\"string\" value=\"${COLLOID_ICONS}\"/>|g" "${XFCE_CONF}/xsettings.xml"
  sed -i 's|<property name="FontName" type="empty"/>|<property name="FontName" type="string" value="Inter 10"/>|g' "${XFCE_CONF}/xsettings.xml"
  sed -i 's|<property name="FontName" type="string" value="[^"]*"/>|<property name="FontName" type="string" value="Inter 10"/>|g' "${XFCE_CONF}/xsettings.xml"
else
  cat > "${XFCE_CONF}/xsettings.xml" << XSEOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="${COLLOID_THEME}"/>
    <property name="IconThemeName" type="string" value="${COLLOID_ICONS}"/>
    <property name="SoundThemeName" type="string" value="default"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Inter 10"/>
    <property name="CursorThemeName" type="string" value="default"/>
  </property>
</channel>
XSEOF
fi

# Window manager theme
if [ -f "${XFCE_CONF}/xfwm4.xml" ]; then
  sed -i "s|<property name=\"theme\" type=\"empty\"/>|<property name=\"theme\" type=\"string\" value=\"${COLLOID_THEME}\"/>|g" "${XFCE_CONF}/xfwm4.xml"
  sed -i "s|<property name=\"theme\" type=\"string\" value=\"[^\"]*\"/>|<property name=\"theme\" type=\"string\" value=\"${COLLOID_THEME}\"/>|g" "${XFCE_CONF}/xfwm4.xml"
  sed -i 's|<property name="title_font" type="empty"/>|<property name="title_font" type="string" value="Inter Bold 9"/>|g' "${XFCE_CONF}/xfwm4.xml"
else
  cat > "${XFCE_CONF}/xfwm4.xml" << XWEOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="${COLLOID_THEME}"/>
    <property name="title_font" type="string" value="Inter Bold 9"/>
  </property>
</channel>
XWEOF
fi

# --------------------------------------------------------------------------
# 6. Configure macOS-style top panel (menu bar)
# --------------------------------------------------------------------------

# macOS layout: slim top panel (menu bar) + Plank dock at bottom
# Top panel: [App Menu | ... spacer ... | System Tray | Clock]
cat > "${XFCE_CONF}/xfce4-panel.xml" << 'PANELEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="28"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="20"/>
        <value type="int" value="15"/>
        <value type="int" value="4"/>
        <value type="int" value="2"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu">
      <property name="button-title" type="string" value="Activities"/>
      <property name="button-icon" type="string" value="/usr/share/extra/icons/icon_default.png"/>
      <property name="show-button-title" type="bool" value="true"/>
    </property>
    <property name="plugin-20" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-15" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray">
      <property name="square-icons" type="bool" value="true"/>
    </property>
    <property name="plugin-2" type="string" value="clock">
      <property name="digital-format" type="string" value="%a %b %d  %I:%M %p"/>
      <property name="mode" type="uint" value="2"/>
    </property>
  </property>
</channel>
PANELEOF

# --------------------------------------------------------------------------
# 7. Configure Plank dock (macOS-style bottom dock)
# --------------------------------------------------------------------------

PLANK_CONF="$HOME/.config/plank/dock1"
mkdir -p "${PLANK_CONF}/launchers"

# Plank settings — transparent theme, bottom position, decent icon size
cat > "${PLANK_CONF}/settings" << 'PLANKEOF'
[PlankDockPreferences]
#shared settings
HideMode=0
UnhideDelay=0
HideDelay=0
Monitor=
Position=3
Offset=0
Alignment=3
IconSize=48
ZoomEnabled=true
ZoomPercent=150
Theme=Transparent
DockItems=files.dockitem;firefox.dockitem;terminal.dockitem;careerclaw.dockitem
PinnedOnly=false
LockItems=false
PressureReveal=false
CurrentWorkspaceOnly=false
PLANKEOF

# Create dock item launchers
cat > "${PLANK_CONF}/launchers/files.dockitem" << 'EOF'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/thunar.desktop
EOF

cat > "${PLANK_CONF}/launchers/firefox.dockitem" << 'EOF'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/firefox.desktop
EOF

cat > "${PLANK_CONF}/launchers/terminal.dockitem" << 'EOF'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/xfce4-terminal.desktop
EOF

cat > "${PLANK_CONF}/launchers/careerclaw.dockitem" << 'EOF'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/careerclaw.desktop
EOF

# Autostart Plank at login
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/plank-dock.desktop << 'AUTOSTART'
[Desktop Entry]
Type=Application
Name=Plank Dock
Comment=macOS-style application dock
Exec=plank
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=2
AUTOSTART

# --------------------------------------------------------------------------
# 8. Install Inter font (clean UI font)
# --------------------------------------------------------------------------

apt-get install -y fonts-inter 2>/dev/null || {
  mkdir -p /usr/share/fonts/truetype/inter
  cd /tmp
  wget -q "https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip" -O inter.zip || true
  if [ -f inter.zip ]; then
    unzip -o inter.zip -d inter_font
    cp inter_font/Inter*.ttf /usr/share/fonts/truetype/inter/ 2>/dev/null || \
    cp inter_font/extras/ttf/*.ttf /usr/share/fonts/truetype/inter/ 2>/dev/null || true
    fc-cache -f
    rm -rf inter.zip inter_font
  fi
}

# --------------------------------------------------------------------------
# 9. Cleanup
# --------------------------------------------------------------------------

chown -R 1000:0 $HOME

if [ -z "${SKIP_CLEAN+x}" ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi

echo "Career-Box macOS-style theme installation complete."
echo "  GTK theme: ${COLLOID_THEME}"
echo "  Icon theme: ${COLLOID_ICONS}"
echo "  Dock: Plank (Transparent theme)"
echo "  Panel: XFCE top menu bar"
