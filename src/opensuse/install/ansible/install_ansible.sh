#!/usr/bin/env bash
set -ex

zypper install -yn ansible
zypper clean --all
