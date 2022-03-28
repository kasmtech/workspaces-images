#!/usr/bin/env bash
set -ex
dpkg --add-architecture i386
apt-get update
apt-get install -y zsnes



