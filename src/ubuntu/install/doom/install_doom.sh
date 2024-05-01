#!/usr/bin/env bash
set -ex

# Install Doom
apt-get update
apt-get install -y chocolate-doom doom-wad-shareware prboom-plus freedoom

# Custom settings
mkdir -p $HOME/.local/share/chocolate-doom
cat >$HOME/.local/share/chocolate-doom/chocolate-doom.cfg <<EOL
force_software_renderer    1
joystick_guid                 "030000005e040000be02000014010000"
joystick_index                0
joystick_x_axis               0
joystick_x_invert             0
joystick_y_axis               1
joystick_y_invert             0
joystick_strafe_axis          -1
joystick_strafe_invert        0
joystick_look_axis            -1
joystick_look_invert          0
joystick_physical_button0     0
joystick_physical_button1     3
joystick_physical_button2     1
joystick_physical_button3     2
joystick_physical_button4     4
joystick_physical_button5     5
joystick_physical_button6     4
joystick_physical_button7     5
joystick_physical_button8     8
joystick_physical_button9     8
joystick_physical_button10    10
joyb_strafeleft               -1
joyb_straferight              -1
joyb_menu_activate            9
joyb_toggle_automap           -1
joyb_prevweapon               6
joyb_nextweapon               7
EOL

cat >$HOME/.local/share/chocolate-doom/default.cfg <<EOL
use_joystick                  1
joyb_fire                     0
joyb_strafe                   2
joyb_use                      1
joyb_speed                    3
EOL

# Startup tweak
cat >/usr/bin/desktop_ready <<EOL
#!/usr/bin/env bash
until pids=\$(pidof Thunar); do sleep .5; done
EOL
chmod +x /usr/bin/desktop_ready

# Desktop icon
DESKTOP_FILE="chocolate-doom.desktop"
if [[ "$(lsb_release -cs)" == @(jammy|noble) ]]; then
  DESKTOP_FILE="org.chocolate_doom.Doom.desktop"
fi
sed -i 's#Exec=chocolate-doom#Exec=/usr/games/chocolate-doom#g' /usr/share/applications/${DESKTOP_FILE}
cp /usr/share/applications/${DESKTOP_FILE} $HOME/Desktop
chmod +x $HOME/Desktop/${DESKTOP_FILE}

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
