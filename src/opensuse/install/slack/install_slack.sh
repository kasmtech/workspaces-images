#!/usr/bin/env bash
set -ex
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

if [ "${ARCH}" == "arm64" ] ; then
    echo "Slack for arm64 currently not supported, skipping install"
    exit 0
fi

# This might prove fragile depending on how often slack changes it's
# website though they don't have a link to always getting the latest version.
# Perhaps a python script that parses the XML could be more robust
#slack_data=$(curl "https://slack.com/downloads/linux")
#version_data=$(grep -oPm1 '(?<=<span class="page-downloads__hero__meta-text__version">)[^<]+' <<< $slack_data)
#version=$(sed -n -e 's/Version //p' <<< $version_data)
#echo "Determined slack latest version to be: ${version}"

# slack latest does not run with --no-sandbox, so we have to hard code to an older version.
version=4.12.2


# This path may not be accurate once arm64 support arrives. Specifically I don't know if it will still be under x64
wget -q https://downloads.slack-edge.com/releases/linux/${version}/prod/x64/slack-${version}-0.1.fc21.x86_64.rpm -O slack.rpm
zypper install -yn libXss1 libsecret-1-0 libappindicator3-1
rpm -i --nodeps slack.rpm
if [ -z ${SKIP_CLEAN+x} ]; then
  zypper clean --all
fi
rm slack.rpm
sed -i 's,/usr/bin/slack,/usr/bin/slack --no-sandbox,g' /usr/share/applications/slack.desktop
cp /usr/share/applications/slack.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/slack.desktop
chown 1000:1000 $HOME/Desktop/slack.desktop
