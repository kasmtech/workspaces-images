#!/usr/bin/env bash
set -xe

# Get latest Cyberbro version
CYBERBRO_VERSION=$(curl -sX GET "https://api.github.com/repos/stanfrbd/cyberbro/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]')

# Install Cyberbro
echo "Install Cyberbro"
apt-get update
apt-get install -y python3-pip git virtualenv
CYBERBRO_HOME=/opt/cyberbro
CYBERBRO_SERVER="http://127.0.0.1:5000"
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

# Set appropriate permissions
chown -R 1000:0 $CYBERBRO_HOME

# Create a launch script
LAUNCH_SCRIPT="$CYBERBRO_HOME/cyberbro-launch.sh"
cat <<EOF > "$LAUNCH_SCRIPT"
#!/usr/bin/env bash
set -ex

check_web_server() {
    curl -s -o /dev/null ${CYBERBRO_SERVER} && return 0 || return 1
}

# Launch Cyberbro server
cd ${CYBERBRO_HOME}/cyberbro-*
source venv/bin/activate
gunicorn -b 127.0.0.1:5000 app:app &

retries=5
count=0
while ! check_web_server && [ \$count -lt \$retries ]; do
  echo "Waiting for web server to start..."
  sleep 1
  count=\$((count + 1))
done

if ! check_web_server; then
  echo "Web server did not start within the expected time."
  exit 1
fi

if [[ "\$#" -gt 0 ]]; then
  firefox ${CYBERBRO_SERVER} "\$@"
else
  firefox ${CYBERBRO_SERVER}
fi
EOF


chmod +x $LAUNCH_SCRIPT
mv $LAUNCH_SCRIPT /usr/local/bin/cyberbro

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

