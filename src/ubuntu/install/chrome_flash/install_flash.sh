#!/usr/bin/env bash
set -ex

# Install the PPAPI plugin via pepperflashplugin-nonfree
# Configure chrome to use the pre-installed version , otherwise it will try and fetch it itself the first time it is
# used which requires internet access, and it may possibly be removed from being downloaded in the future.

echo "deb http://archive.canonical.com/ubuntu/ $(lsb_release -cs) partner" > /etc/apt/sources.list.d/canonical_partner.list
apt-get update
apt-get install -y  pepperflashplugin-nonfree
rm /etc/apt/sources.list.d/canonical_partner.list

FLASH_SO=/usr/lib/pepperflashplugin-nonfree/libpepflashplayer.so
FLASH_VERSION=`strings $FLASH_SO 2> /dev/null | grep LNX | cut -d ' ' -f 2 | sed -e "s/,/./g"`

CHROME_ARGS="--password-store=basic --no-sandbox --disable-gpu --user-data-dir --no-first-run  --ppapi-flash-path=$FLASH_SO --ppapi-flash-version=$FLASH_VERSION"

cat >/usr/bin/google-chrome <<EOL
#!/usr/bin/env bash
/opt/google/chrome/google-chrome ${CHROME_ARGS} "\$@"
EOL
chmod +x /usr/bin/google-chrome
cp /usr/bin/google-chrome /usr/bin/chrome

sed -i 's@exec -a "$0" "$HERE/chrome" "$\@"@@g' /usr/bin/x-www-browser
cat >>/usr/bin/x-www-browser <<EOL
exec -a "\$0" "\$HERE/chrome" "${CHROME_ARGS}"  "\$@"
EOL

# Flash will be enabled for all sites via this policy, but a user still needs to click the widget to run it.
# You can restrict the plugin to only run on authorized sites via the PluginsAllowedForUrls and PluginBLockedForUrls
# settings. These are set to be deprecated in Chrome 88.

# https://cloud.google.com/docs/chrome-enterprise/policies/atomic-groups/#pluginsSettings

echo '{"DefaultPluginsSetting":3}' > /etc/opt/chrome/policies/managed/flash.json

