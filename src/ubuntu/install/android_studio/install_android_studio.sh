#!/usr/bin/env bash
set -ex


ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "$ARCH" == "arm64" ] ; then
  echo "Android studio not supported on arm64, skipping installation"
  exit 0
fi

apt-get update
apt-get install -y  libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 libbz2-1.0:i386 openjdk-18-jdk

# https://developer.android.com/studio/archive
# curl https://developer.android.com/studio | grep android-studio | grep -i "linux.tar.gz" | grep ide-zips | cut -d '"' -f2
ANDROID_STUDIO_DOWNLOAD_URL="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2023.1.1.26/android-studio-2023.1.1.26-linux.tar.gz"

curl -o /tmp/android_studio.tar.gz -L "${ANDROID_STUDIO_DOWNLOAD_URL}"

mkdir -p /opt
cd /tmp
tar -zxvf /tmp/android_studio.tar.gz -C /opt/
rm /tmp/android_studio.tar.gz
ln -sf /opt/android-studio/bin/studio.sh /bin/android-studio
chown 1000:1000 /opt/android-studio


cat >/usr/share/applications/android-studio.desktop <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Comment=Android Studio
Exec=bash -i "/opt/android-studio/bin/studio.sh" %f
Icon=/opt/android-studio/bin/studio.png
Categories=Development;IDE;
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-android-studio
Name[en_GB]=android-studio.desktop
EOL

cp /usr/share/applications/android-studio.desktop $HOME/Desktop/android-studio.desktop
chown 1000:1000 $HOME/Desktop/android-studio.desktop
chmod +x $HOME/Desktop/android-studio.desktop
