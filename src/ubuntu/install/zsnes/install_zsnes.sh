#!/usr/bin/env bash
set -ex
dpkg --add-architecture i386
apt-get update
if [[ "$(lsb_release -cs)" == "bionic" ]];
then
    apt-get install -y maximus
fi
apt-get install -y zsnes



