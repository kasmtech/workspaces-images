#!/bin/bash
set -e

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "$SCRIPT_DIR"

# Wallpaper file name
WALLPAPER_FILE="official_suss_wallpaper.png"

# Source and destination paths
SOURCE_PATH="$SCRIPT_DIR/$WALLPAPER_FILE"
DEST_PATH="/usr/share/images/desktop-base/$WALLPAPER_FILE"
cp "$SOURCE_PATH" "$DEST_PATH"
ln -sf $DEST_PATH /etc/alternatives/desktop-background
chmod 644 $DEST_PATH

# mkdir -p "$(dirname "$DEST_PATH")"

# # Copy the wallpaper file
# # echo "Copying wallpaper to $DEST_PATH..."
# cp "$SOURCE_PATH" "$DEST_PATH"

# # Set the wallpaper
# echo "Setting wallpaper..."
# # Start a D-Bus session
# eval "$(dbus-launch --sh-syntax)"
# export DBUS_SESSION_BUS_ADDRESS
# export DBUS_SESSION_BUS_PID
# gsettings set org.gnome.desktop.background picture-uri "file://$DEST_PATH"
# gsettings set org.gnome.desktop.background picture-options 'scaled'

# # Clean up the D-Bus session
# kill "$DBUS_SESSION_BUS_PID"

echo "Wallpaper has been set successfully!"