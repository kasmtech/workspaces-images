#!/usr/bin/env bash
set -xe

# Get latest Cyberbro version
CYBERBRO_VERSION=$(curl -sX GET "https://api.github.com/repos/stanfrbd/cyberbro/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]')

# Install Cyberbro
echo "Install Cyberbro"
apt-get update
apt-get install -y python3-pip git virtualenv
CYBERBRO_HOME=$HOME/cyberbro
mkdir -p $CYBERBRO_HOME
cd $CYBERBRO_HOME
wget https://github.com/stanfrbd/cyberbro/archive/${CYBERBRO_VERSION}.tar.gz
tar zxvf ${CYBERBRO_VERSION}.tar.gz
rm ${CYBERBRO_VERSION}.tar.gz
cd cyberbro-*

# Enter virtualenv to avoid conflicts with system packages
virtualenv venv
source venv/bin/activate

pip3 install -r requirements.txt

deactivate

# Create mandatory secrets.json
cat <<EOF > secrets.json
{
  "proxy_url": "",
  "gui_enabled_engines": ["reverse_dns", "rdap", "ipquery", "spur", "phishtank", "threatfox", "urlscan", "google", "github", "ioc_one_html", "ioc_one_pdf", "abusix"]
}
EOF

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi

