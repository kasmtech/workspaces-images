#!/usr/bin/env bash
set -ex

ARCH=$(arch  | sed 's/x86_64/amd64/g')

apt-get update
apt-get install -y  android-tools-adb android-tools-fastboot \
                    ffmpeg libsdl2-2.0-0 adb wget \
                    gcc git pkg-config meson ninja-build libsdl2-dev \
                    libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev \
                    libswresample-dev libusb-1.0-0 libusb-1.0-0-dev jq


mkdir -p /opt/
cd /opt/
git clone https://github.com/Genymobile/scrcpy
cd scrcpy
./install_release.sh