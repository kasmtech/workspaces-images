#!/usr/bin/env bash
set -ex

zypper install -yn nano zip wget xdotool
zypper clean --all
