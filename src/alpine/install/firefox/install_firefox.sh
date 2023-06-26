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

# Creating a default profile
firefox -headless -CreateProfile "kasm $HOME/.mozilla/firefox/kasm"
# Generate a certdb to be detected on squid start
HOME=/root firefox --headless &
mkdir -p /root/.mozilla
CERTDB=$(find  /root/.mozilla* -name "cert9.db")
while [ -z "${CERTDB}" ] ; do
  sleep 1
  echo "waiting for certdb"
  CERTDB=$(find  /root/.mozilla* -name "cert9.db")
done
sleep 2
kill $(pgrep firefox)
CERTDIR=$(dirname ${CERTDB})
mv ${CERTDB} $HOME/.mozilla/firefox/kasm/
rm -Rf /root/.mozilla

cat >>$HOME/.mozilla/firefox/profiles.ini <<EOL
[Install4F96D1932A9F858E]
Default=kasm
Locked=1
EOL

# Desktop icon and perms
cp /usr/share/applications/firefox.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/firefox.desktop
chown -R 1000:1000 $HOME/.mozilla
