#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox --use-gl=angle --use-angle=swiftshader --user-data-dir --no-first-run"

apt-get update
apt install -y  apt-transport-https curl

curl -s https://brave-browser-apt-release.s3.brave.com/brave-core.asc |  apt-key --keyring /etc/apt/trusted.gpg.d/brave-browser-release.gpg add -

echo "deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" |  tee /etc/apt/sources.list.d/brave-browser-release.list

apt update

apt install -y  brave-browser

sed -i 's/-stable//g' /usr/share/applications/brave-browser.desktop

cp /usr/share/applications/brave-browser.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/brave-browser.desktop

mv /usr/bin/brave-browser /usr/bin/brave-browser-orig
cat >/usr/bin/brave-browser <<EOL
#!/usr/bin/env bash
/opt/brave.com/brave/brave-browser ${CHROME_ARGS} "\$@"
EOL
chmod +x /usr/bin/brave-browser
cp /usr/bin/brave-browser /usr/bin/brave

sed -i 's@exec -a "$0" "$HERE/brave" "$\@"@@g' /usr/bin/x-www-browser
cat >>/usr/bin/x-www-browser <<EOL
exec -a "\$0" "\$HERE/brave" "${CHROME_ARGS}"  "\$@"
EOL

mkdir -p /etc/chromium/policies/managed/
# Vanilla Chrome looks for policies in /etc/opt/chrome/policies/managed which is used by web filtering.
#   Create a symlink here so filter is applied to brave as well.
mkdir -p /etc/opt/chrome/policies/
ln -s /etc/chromium/policies/managed /etc/opt/chrome/policies/
cat >>/etc/chromium/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL
cat >>/etc/chromium/policies/managed/disable_tor.json <<EOL
{"TorDisabled": true}
EOL

