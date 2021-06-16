#!/usr/bin/env bash
set -ex
apt-get update
apt-get install -y lsyncd



mkdir -p /var/log/lsyncd
chown 1000:1000 /var/log/lsyncd

mkdir -p /etc/lsyncd
cat >/etc/lsyncd/lsyncd.kasm.profile.conf.lua <<EOL
----
-- User configuration file for lsyncd.
--
-- Simple example for default rsync.
--
settings {
            logfile = "/var/log/lsyncd/lsyncd.log",
            statusFile = "/var/log/lsyncd/lsyncd.status",
            statusInterval = 1,
            inotifyMode= "CloseWrite or Modify",
         }

sync {
        default.rsync,
        source="/home/kasm-user/",
        target="/kasm_profile_sync",
        delay = 0,
        rsync={
            verbose = true,
        }
     }

EOL

update-rc.d lsyncd enable

