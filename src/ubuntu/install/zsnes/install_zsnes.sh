#!/usr/bin/env bash
set -ex
dpkg --add-architecture i386
apt-get update
apt-get install -y zsnes

mkdir $HOME/.zsnes

SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPT_PATH="$(realpath $SCRIPT_PATH)"
cp ${SCRIPT_PATH}/zinput.cfg $HOME/.zsnes/zinput.cfg

chown -R 1000:1000 $HOME/.zsnes