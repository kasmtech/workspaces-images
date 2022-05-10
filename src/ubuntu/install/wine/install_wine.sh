#!/bin/bash

# This script currently supports Ubuntu focal only
dpkg --add-architecture i386
apt update
wget -qO- https://dl.winehq.org/wine-builds/winehq.key | apt-key add -
apt install software-properties-common
apt-add-repository "deb http://dl.winehq.org/wine-builds/ubuntu/ $(lsb_release -cs) main"
apt install -y --install-recommends winehq-stable winetricks
