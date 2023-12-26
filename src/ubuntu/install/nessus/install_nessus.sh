#!/usr/bin/env bash
set -ex

ARCH=$(arch  | sed 's/x86_64/amd64/g')

apt-get update
apt-get install -y jq

NESSUS_URL=$(curl --request GET --url https://www.tenable.com/downloads/api/v2/pages/nessus --header 'accept: application/json' | jq -r '.releases.latest[][] | select(.file_url | contains("ubuntu")) | .file_url' | grep $ARCH)
NESSUS_UPDATES_URL=$(curl --request GET --url https://www.tenable.com/downloads/api/v2/pages/nessus --header 'accept: application/json' | jq -r '.releases.latest[][] | select(.file_url | contains("nessus-updates-latest")) | .file_url')

cd /tmp

curl --request GET \
  --url "${NESSUS_URL}" \
  --output 'nessus.deb'

curl --request GET \
  --url ${NESSUS_UPDATES_URL} \
  --output 'nessus-updates-latest.tar.gz'

apt-get install -y ./nessus.deb

rm nessus.deb

/opt/nessus/sbin/nessuscli update /tmp/nessus-updates-latest.tar.gz

rm nessus-updates-latest.tar.gz
