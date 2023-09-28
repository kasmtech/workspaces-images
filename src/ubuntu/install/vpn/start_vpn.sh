#!/usr/bin/env bash

set -ex

# Logging and trap
LOGFILE="/vpn_start.log"
function notify_err() {
  zenity --error --text="An error has occurred configuring the VPN please review the log at ${LOGFILE}"
}
function cleanup_log() {
  rm -f ${LOGFILE}
}
trap notify_err ERR
exec &> >(tee ${LOGFILE})

# If user input is needed for openvpn
function get_set_creds() {
  CREDENTIALS=$(zenity --forms --title="VPN credentials" --text="Enter your VPN auth credentials" --add-entry="Username" --add-password="Password" --separator ",,,,,,")
  USER=$(awk -F',,,,,,' '{print $1}' <<<$CREDENTIALS)
  PASS=$(awk -F',,,,,,' '{print $2}' <<<$CREDENTIALS)
  echo ${USER} > /home/kasm-user/vpn_credentials
  echo ${PASS} >> /home/kasm-user/vpn_credentials
  chown kasm-user:kasm-user /home/kasm-user/vpn_credentials
  cp ${VPN_CONFIG} /home/kasm-user/vpn.ovpn
  chown kasm-user:kasm-user /home/kasm-user/vpn.ovpn
  sed -i "s#auth-user-pass#auth-user-pass /home/kasm-user/vpn_credentials#g" /home/kasm-user/vpn.ovpn
  VPN_CONFIG=/home/kasm-user/vpn.ovpn
}

# Start VPN based on content
if [ ! -z ${VPN_CONFIG+x} ]; then
  if [ "${VPN_CONFIG: -4}" == "conf" ]; then
    echo "wireguard config detected checking for support"
    if ip link add dev test type wireguard; then
      echo "wireguard kernel module is present on this host continuing"
      ip link del dev test
    else
      zenity --error --text="wireguard kernel module is not present on this host and a wireguard config was passed will not continue"
      echo "wireguard kernel module is not present on this host and a wireguard config was passed will not continue"
      exit 1
    fi
    wg-quick up ${VPN_CONFIG}
  fi
  if [ "${VPN_CONFIG: -4}" == "ovpn" ]; then
    # Check if we need user credentials
    if grep -x auth-user-pass ${VPN_CONFIG}; then
      get_set_creds
    fi
    # Create tun device
    if [ ! -c /dev/net/tun ]; then
      mkdir -p /dev/net
      mknod /dev/net/tun c 10 200
    fi
    if which resolvconf; then
      openvpn --pull-filter ignore route-ipv6 --pull-filter ignore ifconfig-ipv6 --config "${VPN_CONFIG}" &
      sleep 10
      if ! pgrep openvpn; then
        zenity --error --text="An error has occurred starting the VPN please review the log at ${LOGFILE}"
	echo "An error has occurred starting the VPN please review the log at ${LOGFILE}"
	exit 1
      fi  
    else
      zenity --error --text="Resolvconf is not found on this system this container is not compatible with wireguard"
      echo "Resolvconf is not found on this system this container is not compatible with wireguard"
      exit 1
    fi
  fi
  if [ "${VPN_CONFIG:0:5}" == "tskey" ]; then
    # Create tun device
    if [ ! -c /dev/net/tun ]; then
      mkdir -p /dev/net
      mknod /dev/net/tun c 10 200
    fi
    tailscaled &
    sleep 2
    tailscale up --authkey=${VPN_CONFIG} 
  fi
else
  zenity --error --text="VPN_CONFIG is not defined there is no tunnel to start"
  echo "VPN_CONFIG is not defined there is no tunnel to start"
  exit 1
fi

# Log success
zenity \
  --info \
  --title "VPN configured" \
  --text "VPN connected!"
echo "VPN started using the config file ${VPN_CONFIG}"
cleanup_log
