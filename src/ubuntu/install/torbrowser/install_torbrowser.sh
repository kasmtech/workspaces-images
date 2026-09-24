#!/usr/bin/env bash
set -xe
echo "Install TorBrowser"

apt-get install -y xz-utils curl
TOR_HOME=$HOME/tor-browser/
mkdir -p $TOR_HOME
# Detect architecture and set platform name
ARCH=$(arch)
if [ "$ARCH" == "aarch64" ]; then
  TOR_PLATFORM="aarch64"
else
  TOR_PLATFORM="x86_64"
fi

# Get latest Tor Browser version from official distribution server
TORBROWSER_VERSION=$(curl -s "https://dist.torproject.org/torbrowser/" | \
    grep -oP '(?<=href=")[^"]*/' | \
    grep -v "^noscript" | \
    grep -v "^/" | \
    cut -d'/' -f1 | \
    sort -V | \
    tail -1)

echo "Using Tor Browser version: $TORBROWSER_VERSION for $TOR_PLATFORM"

# Construct official download URL
FULL_TOR_URL="https://dist.torproject.org/torbrowser/${TORBROWSER_VERSION}/tor-browser-linux-${TOR_PLATFORM}-${TORBROWSER_VERSION}.tar.xz"
wget --quiet "${FULL_TOR_URL}" -O /tmp/torbrowser.tar.xz
tar -xJf /tmp/torbrowser.tar.xz -C $TOR_HOME
rm /tmp/torbrowser.tar.xz


cp $TOR_HOME/tor-browser/start-tor-browser.desktop $TOR_HOME/tor-browser/start-tor-browser.desktop.bak
cp $TOR_HOME/tor-browser/Browser/browser/chrome/icons/default/default128.png /usr/share/icons/tor.png
chown 1000:0 /usr/share/icons/tor.png
sed -i 's/^Name=.*/Name=Tor Browser/g' $TOR_HOME/tor-browser/start-tor-browser.desktop
sed -i 's/Icon=.*/Icon=\/usr\/share\/icons\/tor.png/g' $TOR_HOME/tor-browser/start-tor-browser.desktop
sed -i 's/Exec=.*/Exec=sh -c \x27"$HOME\/tor-browser\/tor-browser\/Browser\/start-tor-browser" --detach || ([ !  -x "$HOME\/tor-browser\/tor-browser\/Browser\/start-tor-browser" ] \&\& "$(dirname "$*")"\/Browser\/start-tor-browser --detach)\x27 dummy %k/g'  $TOR_HOME/tor-browser/start-tor-browser.desktop


cat >> $TOR_HOME/tor-browser/Browser/TorBrowser/Data/Browser/profile.default/prefs.js <<EOL
user_pref("app.update.download.promptMaxAttempts", 0);
user_pref("app.update.elevation.promptMaxAttempts", 0);
user_pref("app.update.checkInstallTime", false);
user_pref("app.update.background.interval", 315360000);
user_pref("extensions.torlauncher.prompt_at_startup", false);
user_pref("extensions.torlauncher.quickstart", true);
user_pref("browser.download.lastDir", "/home/kasm-user/Downloads");
user_pref("torbrowser.settings.bridges.builtin_type", "");
user_pref("torbrowser.settings.bridges.enabled", false);
user_pref("torbrowser.settings.bridges.source", -1);
user_pref("torbrowser.settings.enabled", true);
user_pref("torbrowser.settings.firewall.enabled", false);
user_pref("torbrowser.settings.proxy.enabled", false);
user_pref("torbrowser.settings.quickstart.enabled", true);
EOL

# Maintain backwards compatability with old image definitions that expect tor to be launched from /tmp
mkdir -p /tmp/tor-browser/Browser/
ln -s $TOR_HOME/tor-browser/start-tor-browser.desktop /tmp/tor-browser/Browser/start-tor-browser.desktop 

chown -R 1000:0 $TOR_HOME/


cp $TOR_HOME/tor-browser/start-tor-browser.desktop $HOME/Desktop/
chown 1000:0  $HOME/Desktop/start-tor-browser.desktop

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
