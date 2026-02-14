#!/usr/bin/env bash
set -ex

# ============================================================================
# Zorin OS Theme for Kasm Workspaces
# Installs zorin-desktop-themes, zorin-icon-themes, zorin-os-wallpapers
# from the official Zorin PPA (ppa:zorinos/stable)
# Works with core-ubuntu-jammy (22.04) and core-ubuntu-noble (24.04)
# ============================================================================

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

UBUNTU_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
echo "Detected Ubuntu: ${UBUNTU_CODENAME} (${ARCH})"

# --------------------------------------------------------------------------
# 1. Add Zorin PPA and install theme packages
# --------------------------------------------------------------------------

apt-get update
apt-get install -y software-properties-common

add-apt-repository -y ppa:zorinos/stable
apt-get update

apt-get install -y \
  zorin-desktop-themes \
  zorin-icon-themes \
  zorin-os-wallpapers \
  gtk2-engines-murrine \
  gtk2-engines-pixbuf

# --------------------------------------------------------------------------
# 2. Set Zorin wallpaper as default background
# --------------------------------------------------------------------------

# Find the best Zorin wallpaper to use as default
# Kasm always looks for bg_default.png, so we must use that exact name
ZORIN_BG=""
for candidate in \
  /usr/share/backgrounds/Zorin-Dark.jpg \
  /usr/share/backgrounds/Zorin.jpg \
  /usr/share/backgrounds/Planet-Zorin.jpg; do
  if [ -f "${candidate}" ]; then
    ZORIN_BG="${candidate}"
    break
  fi
done

if [ -n "${ZORIN_BG}" ]; then
  # Must be named bg_default.png — Kasm hardcodes this path
  cp "${ZORIN_BG}" /usr/share/backgrounds/bg_default.png
  echo "Set wallpaper: ${ZORIN_BG}"
else
  echo "WARNING: No Zorin wallpaper found, keeping Kasm default"
  ls -la /usr/share/backgrounds/ || true
fi

# --------------------------------------------------------------------------
# 3. Configure XFCE to use ZorinBlue-Dark theme
# --------------------------------------------------------------------------

XFCE_CONF="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "${XFCE_CONF}"

# GTK theme + icon theme via xsettings
# The Kasm base image uses type="empty" (no value) for most properties.
# We need to replace both type="empty"/> AND type="string" value="..."/>
if [ -f "${XFCE_CONF}/xsettings.xml" ]; then
  # Replace ThemeName whether it's type="empty" or type="string"
  sed -i 's|<property name="ThemeName" type="empty"/>|<property name="ThemeName" type="string" value="ZorinBlue-Dark"/>|g' "${XFCE_CONF}/xsettings.xml"
  sed -i 's|<property name="ThemeName" type="string" value="[^"]*"/>|<property name="ThemeName" type="string" value="ZorinBlue-Dark"/>|g' "${XFCE_CONF}/xsettings.xml"
  # Replace IconThemeName
  sed -i 's|<property name="IconThemeName" type="empty"/>|<property name="IconThemeName" type="string" value="ZorinBlue-Dark"/>|g' "${XFCE_CONF}/xsettings.xml"
  sed -i 's|<property name="IconThemeName" type="string" value="[^"]*"/>|<property name="IconThemeName" type="string" value="ZorinBlue-Dark"/>|g' "${XFCE_CONF}/xsettings.xml"
  # Replace FontName
  sed -i 's|<property name="FontName" type="empty"/>|<property name="FontName" type="string" value="Inter 10"/>|g' "${XFCE_CONF}/xsettings.xml"
  sed -i 's|<property name="FontName" type="string" value="[^"]*"/>|<property name="FontName" type="string" value="Inter 10"/>|g' "${XFCE_CONF}/xsettings.xml"
else
  cat > "${XFCE_CONF}/xsettings.xml" << 'XSEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="ZorinBlue-Dark"/>
    <property name="IconThemeName" type="string" value="ZorinBlue-Dark"/>
    <property name="SoundThemeName" type="string" value="default"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Inter 10"/>
    <property name="CursorThemeName" type="string" value="default"/>
  </property>
</channel>
XSEOF
fi

# Window manager (xfwm4) theme
if [ -f "${XFCE_CONF}/xfwm4.xml" ]; then
  sed -i 's|<property name="theme" type="empty"/>|<property name="theme" type="string" value="ZorinBlue-Dark"/>|g' "${XFCE_CONF}/xfwm4.xml"
  sed -i 's|<property name="theme" type="string" value="[^"]*"/>|<property name="theme" type="string" value="ZorinBlue-Dark"/>|g' "${XFCE_CONF}/xfwm4.xml"
  sed -i 's|<property name="title_font" type="empty"/>|<property name="title_font" type="string" value="Inter Bold 9"/>|g' "${XFCE_CONF}/xfwm4.xml"
else
  cat > "${XFCE_CONF}/xfwm4.xml" << 'XWEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="ZorinBlue-Dark"/>
    <property name="title_font" type="string" value="Inter Bold 9"/>
  </property>
</channel>
XWEOF
fi

# --------------------------------------------------------------------------
# 4. Configure Zorin-style bottom taskbar panel
# --------------------------------------------------------------------------

# Replace the Kasm default top panel with a Zorin-style bottom panel:
# [App Menu | Tasklist (window buttons) | ... | System Tray | Clock]
cat > "${XFCE_CONF}/xfce4-panel.xml" << 'PANELEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=8;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="36"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="20"/>
        <value type="int" value="3"/>
        <value type="int" value="15"/>
        <value type="int" value="4"/>
        <value type="int" value="2"/>
        <value type="int" value="5"/>
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
    <property name="plugin-3" type="string" value="tasklist">
      <property name="show-labels" type="bool" value="true"/>
      <property name="flat-buttons" type="bool" value="true"/>
      <property name="show-handle" type="bool" value="false"/>
    </property>
    <property name="plugin-15" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray">
      <property name="square-icons" type="bool" value="true"/>
    </property>
    <property name="plugin-2" type="string" value="clock">
      <property name="digital-format" type="string" value="%b %d  %I:%M %p"/>
      <property name="mode" type="uint" value="2"/>
    </property>
    <property name="plugin-5" type="string" value="showdesktop"/>
  </property>
</channel>
PANELEOF

# --------------------------------------------------------------------------
# 5. Install Inter font (Zorin's default UI font)
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
# 5. Cleanup
# --------------------------------------------------------------------------

chown -R 1000:0 $HOME

if [ -z "${SKIP_CLEAN+x}" ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi

echo "Zorin OS theme installation complete."
