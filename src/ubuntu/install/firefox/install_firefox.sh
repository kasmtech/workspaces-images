#!/usr/bin/env bash
set -xe

# Add icon
if [ -f /dockerstartup/install/ubuntu/install/firefox/firefox.desktop ]; then
  mv /dockerstartup/install/ubuntu/install/firefox/firefox.desktop $HOME/Desktop/
fi

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

set_desktop_icon() {
  sed -i -e 's!Icon=.\+!Icon=/usr/share/icons/hicolor/48x48/apps/firefox.png!' "$HOME/Desktop/firefox.desktop"
}

echo "Install Firefox"
if [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
  if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
    dnf install -y firefox p11-kit
  else
    yum install -y firefox p11-kit
  fi
elif [ "${DISTRO}" == "opensuse" ]; then
  zypper install -yn p11-kit-tools MozillaFirefox
elif grep -q Jammy /etc/os-release; then
  if [ ! -f '/etc/apt/preferences.d/mozilla-firefox' ]; then
    add-apt-repository -y ppa:mozillateam/ppa
    echo '
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
' > /etc/apt/preferences.d/mozilla-firefox
  fi
  apt-get install -y firefox p11-kit-modules
elif grep -q "ID=debian" /etc/os-release || grep -q "ID=kali" /etc/os-release || grep -q "ID=parrot" /etc/os-release; then
  echo \
    "deb http://deb.debian.org/debian/ unstable main contrib non-free" >> \
    /etc/apt/sources.list
cat > /etc/apt/preferences.d/99pin-unstable <<EOF
Package: *
Pin: release a=stable
Pin-Priority: 900

Package: *
Pin: release a=unstable
Pin-Priority: 10
EOF
  apt-get update
  apt-get install -y -t unstable firefox p11-kit-modules
else
  apt-mark unhold firefox || :
  apt-get remove firefox
  apt-get update
  apt-get install -y firefox p11-kit-modules
fi

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

# Cleanup and install flash if supported
if [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
  if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
    if [ -z ${SKIP_CLEAN+x} ]; then
      dnf clean all
    fi
  else
    if [ -z ${SKIP_CLEAN+x} ]; then
      yum clean all
    fi
  fi
elif [ "${DISTRO}" == "opensuse" ]; then
  if [ -z ${SKIP_CLEAN+x} ]; then
    zypper clean --all
  fi
else
  if [ "$ARCH" == "arm64" ] && [ "$(lsb_release -cs)" == "focal" ] ; then
    echo "Firefox flash player not supported on arm64 Ubuntu Focal Skipping"
  elif grep -q "ID=debian" /etc/os-release || grep -q "ID=kali" /etc/os-release || grep -q "ID=parrot" /etc/os-release; then
    echo "Firefox flash player not supported on Debian"
  elif ! grep -q Jammy /etc/os-release; then
    # Plugin to support running flash videos for sites like vimeo 
    apt-get update
    apt-get install -y browser-plugin-freshplayer-pepperflash
    apt-mark hold firefox
    if [ -z ${SKIP_CLEAN+x} ]; then
      apt-get autoclean
      rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/*
    fi
  fi
fi

if [[ "${DISTRO}" != @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|opensuse|fedora37|fedora38|fedora39) ]]; then
  # Update firefox to utilize the system certificate store instead of the one that ships with firefox
  rm -f /usr/lib/firefox/libnssckbi.so
  ln /usr/lib/$(arch)-linux-gnu/pkcs11/p11-kit-trust.so /usr/lib/firefox/libnssckbi.so
fi

if [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|fedora37|fedora38|fedora39) ]]; then
  if [[ "${DISTRO}" == @(fedora37|fedora38|fedora39) ]]; then
    preferences_file=/usr/lib64/firefox/browser/defaults/preferences/firefox-redhat-default-prefs.js
  else
    preferences_file=/usr/lib64/firefox/browser/defaults/preferences/all-redhat.js
  fi
  sed -i -e '/homepage/d' "$preferences_file"
elif [ "${DISTRO}" == "opensuse" ]; then
  preferences_file=/usr/lib64/firefox/browser/defaults/preferences/firefox.js
else
  preferences_file=/usr/lib/firefox/browser/defaults/preferences/firefox.js
fi

# Disabling default first run URL for Debian based images
if [[ "${DISTRO}" != @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|opensuse|fedora37|fedora38|fedora39) ]]; then
cat >"$preferences_file" <<EOF
pref("datareporting.policy.firstRunURL", "");
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("datareporting.healthreport.service.enabled", false);
pref("datareporting.healthreport.uploadEnabled", false);
pref("trailhead.firstrun.branches", "nofirstrun-empty");
pref("browser.aboutwelcome.enabled", false);
EOF
fi

if [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|opensuse|fedora37|fedora38|fedora39) ]]; then
  # Creating a default profile
  chown -R root:root $HOME
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
else
  # Creating Default Profile
  chown -R 0:0 $HOME
  firefox -headless -CreateProfile "kasm $HOME/.mozilla/firefox/kasm"
fi

if [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|opensuse|fedora37|fedora38|fedora39) ]]; then
  set_desktop_icon
fi

# Starting with version 67, Firefox creates a unique profile mapping per installation which is hash generated
#   based off the installation path. Because that path will be static for our deployments we can assume the hash
#   and thus assign our profile to the default for the installation

if [[ "${DISTRO}" != @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|opensuse|fedora37|fedora38|fedora39) ]]; then
cat >>$HOME/.mozilla/firefox/profiles.ini <<EOL
[Install4F96D1932A9F858E]
Default=kasm
Locked=1
EOL
elif [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|almalinux9|almalinux8|opensuse|fedora37|fedora38|fedora39) ]]; then
cat >>$HOME/.mozilla/firefox/profiles.ini <<EOL
[Install11457493C5A56847]
Default=kasm
Locked=1
EOL
fi

# Desktop Icon FIxes
if [[ "${DISTRO}" == @(rockylinux9|oracle9|almalinux9|fedora39) ]]; then
  sed -i 's#Icon=/usr/lib/firefox#Icon=/usr/lib64/firefox#g' $HOME/Desktop/firefox.desktop
fi

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
if [ -f $HOME/Desktop/firefox.desktop ]; then
  chmod +x $HOME/Desktop/firefox.desktop
fi
chown -R 1000:1000 $HOME/.mozilla

