#!/usr/bin/env bash
set -ex

# Install Telegram
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "${ARCH}" == "arm64" ] ; then
  # Telegram is not available for noble aarch64
  if grep -q "VERSION_CODENAME=noble" /etc/os-release; then
    exit 0
  fi
  apt-get update
  apt-get install -y telegram-desktop
  if grep -q bookworm /etc/os-release; then
    cp /usr/share/applications/org.telegram.desktop.desktop $HOME/Desktop/telegram.desktop
  else
    cp /usr/share/applications/telegramdesktop.desktop $HOME/Desktop/telegram.desktop
  fi
  chmod +x $HOME/Desktop/telegram.desktop
else
  curl -L https://telegram.org/dl/desktop/linux -o /tmp/telegram.tgz
  tar -xvf /tmp/telegram.tgz -C /opt/
  rm -rf /tmp/telegram.tgz

  curl -L https://kasm-static-content.s3.amazonaws.com/icons/telegram.png -o /opt/Telegram/telegram_icon.png
  cat >/usr/share/applications/telegram.desktop <<EOL
[Desktop Entry]
Version=1.0
Name=Telegram Desktop
Comment=Official desktop version of Telegram messaging app
TryExec=/opt/Telegram/Telegram
Exec=/opt/Telegram/Telegram -- %u
Icon=/opt/Telegram/telegram_icon.png
Terminal=false
StartupWMClass=TelegramDesktop
Type=Application
Categories=Chat;Network;InstantMessaging;Qt;
MimeType=x-scheme-handler/tg;
Keywords=tg;chat;im;messaging;messenger;sms;tdesktop;
X-GNOME-UsesNotifications=true
EOL
  chmod +x /usr/share/applications/telegram.desktop
  cp /usr/share/applications/telegram.desktop $HOME/Desktop/telegram.desktop
fi

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
