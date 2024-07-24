#!/bin/bash
set -e

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wallpaper file name
WALLPAPER_FILE="official_suss_wallpaper.png"

# Source and destination paths
SOURCE_PATH="$SCRIPT_DIR/$WALLPAPER_FILE"
DEST_PATH="$HOME/background/$WALLPAPER_FILE"

# Copy the wallpaper file
echo "Copying wallpaper to $DEST_PATH..."
cp "$SOURCE_PATH" "$DEST_PATH"

# Set the wallpaper
echo "Setting wallpaper..."
gsettings set org.gnome.desktop.background picture-uri "file://$DEST_PATH"
gsettings set org.gnome.desktop.background picture-options 'scaled'

echo "Wallpaper has been set successfully!"