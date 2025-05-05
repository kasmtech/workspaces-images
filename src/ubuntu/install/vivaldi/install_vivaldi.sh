#!/usr/bin/env bash
set -ex

VIVALDI_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"

# Install Vivaldi (Ubuntu)
wget -qO- https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor > /usr/share/keyrings/vivaldi-browser.gpg
echo "deb [signed-by=/usr/share/keyrings/vivaldi-browser.gpg arch=$(dpkg --print-architecture)] https://repo.vivaldi.com/archive/deb/ stable main" > /etc/apt/sources.list.d/vivaldi-archive.list
apt-get update && apt-get install -y vivaldi-stable
mkdir -p /var/opt/vivaldi
set +e
for i in {1..120}; do
    /opt/vivaldi/update-ffmpeg
    if [ $? -eq 0 ]; then
        break
    fi
    sleep 1
done
set -e

# Add Desktop Icon
cp /usr/share/applications/vivaldi-stable.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/vivaldi-stable.desktop
chmod +x $HOME/Desktop/vivaldi-stable.desktop

# Use wrapper to launch application
mv /opt/vivaldi/vivaldi /opt/vivaldi/vivaldi-orig
cat >/opt/vivaldi/vivaldi <<EOL
#!/usr/bin/env bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/vivaldi/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/vivaldi/Default/Preferences
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Vivaldi with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /opt/vivaldi/vivaldi-orig ${CHROME_ARGS} "\$@" 
else
    echo "Starting Vivaldi"
    /opt/vivaldi/vivaldi-orig ${VIVALDI_ARGS} "\$@"
fi
EOL
chmod +x /opt/vivaldi/vivaldi

# Set mime type to launch web content
sed -i 's@exec -a "$0" "$HERE/vivaldi" "$\@"@@g' /usr/bin/x-www-browser
cat >>/usr/bin/x-www-browser <<EOL
  exec -a "\$0" "\$HERE/vivaldi" "${VIVALDI_ARGS}"  "\$@"
EOL

# Set chrome managed policies for vivaldi
mkdir -p /etc/opt/chrome/policies/managed/
cat >>/etc/opt/chrome/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL

# Cleanup
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*
fi

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
