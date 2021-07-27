#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox --use-gl=angle --use-angle=swiftshader  --user-data-dir --no-first-run"

apt-get update

EDGE_BUILD=$(curl -q https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-dev/ | grep href | grep .deb | sed 's/.*href="//g'  | cut -d '"' -f1 | tail -1)

wget -q -O edge.deb https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-dev/$EDGE_BUILD
apt-get install -y ./edge.deb
rm edge.deb

cp /usr/share/applications/microsoft-edge-dev.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/microsoft-edge-dev.desktop

mv /usr/bin/microsoft-edge-dev  /usr/bin/microsoft-edge-dev-orig
cat >/usr/bin/microsoft-edge-dev <<EOL
#!/usr/bin/env bash
/opt/microsoft/msedge-dev/microsoft-edge ${CHROME_ARGS} "\$@"
EOL
chmod +x /usr/bin/microsoft-edge-dev
#cp /usr/bin/microsoft-edge-dev /usr/bin/microsoft-edge

sed -i 's@exec -a "$0" "$HERE/microsoft-edge" "$\@"@@g' /usr/bin/x-www-browser
cat >>/usr/bin/x-www-browser <<EOL
exec -a "\$0" "\$HERE/microsoft-edge" "${CHROME_ARGS}"  "\$@"
EOL


mkdir -p /etc/opt/edge/policies/managed/
cat >>/etc/opt/edge/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL

# Vanilla Chrome looks for policies in /etc/opt/chrome/policies/managed which is used by web filtering.
#   Create a symlink here so filter is applied to edge as well.
mkdir -p /etc/opt/chrome/policies/
ln -s /etc/opt/edge/policies/managed  /etc/opt/chrome/policies/

