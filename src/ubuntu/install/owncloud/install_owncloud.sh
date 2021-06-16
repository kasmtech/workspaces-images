#!/usr/bin/env bash
### every exit != 0 fails the script
set -ex
wget -nv https://download.opensuse.org/repositories/isv:ownCloud:desktop/Ubuntu_17.04/Release.key -O Release.key
apt-key add - < Release.key
apt-get update
sh -c "echo 'deb http://download.opensuse.org/repositories/isv:/ownCloud:/desktop/Ubuntu_16.04/ /' > /etc/apt/sources.list.d/isv:ownCloud:desktop.list"
apt-get update
apt-get install -y owncloud-client
mkdir -p $HOME/.config/ownCloud

cat >$HOME/.config/ownCloud/owncloud.cfg  <<EOL
[General]
clientVersion=2.5.1 (build 10450)
confirmExternalStorage=true
newBigFolderSizeLimit=500
optionalDesktopNotifications=true
useNewBigFolderSizeLimit=true

[Accounts]
0\Folders\1\ignoreHiddenFiles=false
0\Folders\1\journalPath=._sync_5cbcdaef8f19.db
0\Folders\1\localPath=/home/kasm-user/ownCloud/
0\Folders\1\paused=false
0\Folders\1\targetPath=/
0\Folders\1\usePlaceholders=false
0\Folders\1\version=1
0\authType=http
0\dav_user=user
0\http_oauth=false
0\http_user=user
0\serverVersion=10.0.10.4
0\url=http://192.168.117.130:9999
0\user=user
0\version=1
version=2

[ActivityListHeader]
geometry=@ByteArray(\0\0\0\xff\0\0\0\0\0\0\0\x1\0\0\0\x1\0\0\0\0\x1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x2\x8b\0\0\0\x5\x1\x1\0\x1\0\0\0\0\0\0\0\0\0\0\0\0\x64\xff\xff\xff\xff\0\0\0\x81\0\0\0\0\0\0\0\x5\0\0\0}\0\0\0\x1\0\0\0\0\0\0\0\xb4\0\0\0\x1\0\0\0\0\0\0\0\x64\0\0\0\x1\0\0\0\0\0\0\0\x64\0\0\0\x1\0\0\0\0\0\0\0\x92\0\0\0\x1\0\0\0\0\0\0\x3\xe8\0\0\0\0\x64)

[Settings]
geometry=@ByteArray(\x1\xd9\xd0\xcb\0\x2\0\0\0\0\0P\0\0\x1\x13\0\0\x3\b\0\0\x2\xf7\0\0\0R\0\0\x1%\0\0\x3\x6\0\0\x2\xf5\0\0\0\0\0\0\0\0\x3Y)

EOL

touch $HOME/.config/ownCloud/sync-exclude.lst

chown -R 1000:1000 $HOME/.config/
