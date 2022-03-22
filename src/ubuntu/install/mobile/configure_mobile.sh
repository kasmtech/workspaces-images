#!/usr/bin/env bash
# Installs a virtual keyboard
# Installs and configures accessibility options so the keyboard pops up when a text box is clicked

set -ex

# mousetweaks  - used to simulate right mouse clicking when holding down left mouse click button
# onboard - on screen keyboard
# unclutter - Remove Mouse Cursor. This configuration will remove the cursor except for briefly when its clicked

apt-get update
apt-get install -y dconf-cli dconf-editor libglib2.0-bin mousetweaks onboard unclutter

rm -f /etc/xdg/autostart/orca-autostart.desktop


# Configure Onboard Virtual Keyboard Settings
dbus-launch gsettings set org.gnome.desktop.interface toolkit-accessibility true
dbus-launch gsettings set org.onboard.window docking-enabled true
dbus-launch gsettings set org.onboard.window docking-shrink-workarea false
dbus-launch gsettings set org.onboard.window docking-edge 'bottom'
dbus-launch gsettings set org.onboard.window force-to-top true
dbus-launch gsettings set org.onboard.window.landscape dock-expand true
dbus-launch gsettings set org.onboard.auto-show enabled true
dbus-launch gsettings set org.onboard xembed-onboard true
dbus-launch gsettings set org.onboard theme 'Nightshade'
dbus-launch gsettings set org.onboard use-system-defaults false
dbus-launch gsettings set org.onboard layout '/usr/share/onboard/layouts/Phone.onboard'
#dbus-launch gsettings get org.gnome.desktop.a11y.applications screen-reader-enabled



# Install and configure orca screen reader. Needed for text box triggering of keyboard when entering/exiting text areas
apt-get install -y gnome-orca
sed -i "s@OnlyShowIn@#OnlyShowIn@" /etc/xdg/autostart/orca-autostart.desktop
cat /etc/xdg/autostart/orca-autostart.desktop

# Turn on accessibility options in XFCE
cat >$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml <<EOL
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="StartAssistiveTechnologies" type="bool" value="true"/>
  </property>
</channel>
EOL

chown 1000:1000 $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
chown -R 1000:1000 $HOME/.config/dconf
chown -R 1000:1000 $HOME/.cache

# Disable the speech within Orca so every window/input isnt annotated
mkdir -p $HOME/.local/share/orca
echo '{"general":{"enableSpeech": false}}' > $HOME/.local/share/orca/user-settings.conf
chown -R 1000:1000 $HOME/.local/share/orca/
