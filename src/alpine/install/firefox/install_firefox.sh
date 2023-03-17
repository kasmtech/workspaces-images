#!/usr/bin/env bash
set -xe

apk add --no-cache \
  firefox

# Disabling default first run URL
cat >/usr/lib/firefox/browser/defaults/preferences/vendor.js <<EOF
pref("datareporting.policy.firstRunURL", "");
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("datareporting.healthreport.service.enabled", false);
pref("datareporting.healthreport.uploadEnabled", false);
pref("trailhead.firstrun.branches", "nofirstrun-empty");
pref("browser.aboutwelcome.enabled", false);
EOF

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
