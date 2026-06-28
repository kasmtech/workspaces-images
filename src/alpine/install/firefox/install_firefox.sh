#!/usr/bin/env bash
set -xe

apk add --no-cache \
  firefox

# Add Langpacks
FIREFOX_VERSION=$(curl -sI https://download.mozilla.org/?product=firefox-latest | awk -F '(releases/|/win32)' '/Location/ {print $2}')
RELEASE_URL="https://releases.mozilla.org/pub/firefox/releases/${FIREFOX_VERSION}/win64/xpi/"
LANGS=$(curl -Ls ${RELEASE_URL} | awk -F '(xpi">|</a>)' '/href.*xpi/ {print $2}' | tr '\n' ' ')
EXTENSION_DIR=/usr/lib/firefox-addons/distribution/extensions/
mkdir -p ${EXTENSION_DIR}
for LANG in ${LANGS}; do
  LANGCODE=$(echo ${LANG} | sed 's/\.xpi//g')
  echo "Downloading ${LANG} Language pack"
  curl -o \
    ${EXTENSION_DIR}langpack-${LANGCODE}@firefox.mozilla.org.xpi -Ls \
    ${RELEASE_URL}${LANG}
done

# Firefox 147+ introduced XDG base dir support, so profile paths will vary and need to be handled appropriately
FIREFOX_VERSION=$(firefox --version | awk '{print $3}')
FIREFOX_MAJOR=$(echo "$FIREFOX_VERSION" | cut -d. -f1)
if [[ "${FIREFOX_MAJOR:-0}" -ge 147 ]]; then
  FIREFOX_PROFILE_BASE="$HOME/.config/mozilla/firefox"
else
  FIREFOX_PROFILE_BASE="$HOME/.mozilla/firefox"
fi
FIREFOX_PROFILE_PATH="$FIREFOX_PROFILE_BASE/kasm"
FIREFOX_PROFILES_INI="$FIREFOX_PROFILE_BASE/profiles.ini"

# Creating a default profile
firefox -headless -CreateProfile "kasm $FIREFOX_PROFILE_PATH"

# For alpine 3.20 and later, firefox version shows a security nag. Silence it..
if [[ "$(printf '%s\n' 3.20 $(cat /etc/alpine-release) | sort -V | head -n 1)" = "3.20" ]]; then
  echo 'user_pref("security.sandbox.warn_unprivileged_namespaces", false);' > "$FIREFOX_PROFILE_PATH/user.js"
  chown 1000:1000 "$FIREFOX_PROFILE_PATH/user.js"
fi
  
if [[ "${FIREFOX_MAJOR:-0}" -ge 147 ]]; then
  ROOT_CERTDB_BASE="/root/.config/mozilla"
else
  ROOT_CERTDB_BASE="/root/.mozilla"
fi
HOME=/root firefox --headless &
mkdir -p "$ROOT_CERTDB_BASE"
CERTDB=$(find "$ROOT_CERTDB_BASE" -name "cert9.db")
while [[ -z "${CERTDB}" ]] ; do
  sleep 1
  echo "waiting for certdb"
  CERTDB=$(find "$ROOT_CERTDB_BASE" -name "cert9.db")
done
sleep 2
kill $(pgrep firefox)
CERTDIR=$(dirname ${CERTDB})
mv ${CERTDB} $FIREFOX_PROFILE_PATH/
rm -Rf "$ROOT_CERTDB_BASE"

cat >>"$FIREFOX_PROFILES_INI" <<EOL
[Install4F96D1932A9F858E]
Default=kasm
Locked=1
EOL

# Desktop icon and perms
cp /usr/share/applications/firefox.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/firefox.desktop
if [[ -d "$HOME/.mozilla" ]]; then
  chown -R 1000:1000 "$HOME/.mozilla"
fi
if [[ -d "$HOME/.config/mozilla" ]]; then
  chown -R 1000:1000 "$HOME/.config/mozilla"
fi
