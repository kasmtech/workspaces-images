#!/usr/bin/env bash
set -ex

apt-get update
apt-get install -y rdesktop


wget https://download3.vmware.com/software/view/viewclients/CART22FH2/VMware-Horizon-Client-2111-8.4.0-18957622.x64.bundle -O horizons.bundle
chmod +x ./horizons.bundle

export TERM=dumb
export VMWARE_EULAS_AGREED=yes
./horizons.bundle  --console  --eulas-agreed --required --stop-services	 \
--set-setting vmware-horizon-usb usbEnable yes \
--set-setting vmware-horizon-smartcard smartcardEnable yes \
--set-setting vmware-horizon-rtav rtavEnable yes \
--set-setting vmware-horizon-tsdr tsdrEnable yes \
--set-setting vmware-horizon-scannerclient scannerEnable yes \
--set-setting vmware-horizon-serialportclient serialportEnable yes \
--set-setting vmware-horizon-mmr mmrEnable yes \
--set-setting vmware-horizon-media-provider mediaproviderEnable yes \
--set-setting vmware-horizon-integrated-printing vmipEnable yes \
--set-setting vmware-horizon-html5mmr html5mmrEnable yes

rm -f ./horizons.bundle


cp /usr/share/applications/vmware-view.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/vmware-view.desktop