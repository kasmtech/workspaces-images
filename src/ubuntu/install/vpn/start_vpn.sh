#!/usr/bin/env bash
set -x

ICON_SUCCESS="/usr/share/icons/ubuntu-mono-dark/status/22/nm-signal-100-secure.svg"
ICON_ERROR="/usr/share/icons/ubuntu-mono-dark/status/22/network-error.svg"
ICON_OFFLINE="/usr/share/icons/ubuntu-mono-dark/status/22/network-offline.svg"
OPENVPN_STATUS_LOG="/tmp/openvpn-status.log"
DEFAULT_OPENVPN_CONFIG="/dockerstartup/openvpn.conf"
DEFAULT_OPENVPN_CREDS="/dockerstartup/openvpn-auth"
DEFAULT_WIREGUARD_CONFIG="/dockerstartup/wireguard.conf"

SHOW_VPN_STATUS_DEFAULT="1"
SHOW_VPN_STAT=${SHOW_VPN_STATUS:-$SHOW_VPN_STATUS_DEFAULT}

SHOW_IP_STATUS_DEFAULT="1"
SHOW_IP_STAT=${SHOW_IP_STATUS:-$SHOW_IP_STATUS_DEFAULT}

# Logging and trap
LOGFILE="/dockerstartup/vpn_start.log"
function notify_err() {
  local exit_code=$?
  local failed_command="$BASH_COMMAND"
  msg="An error occurred with exit code $exit_code while executing: $failed_command.\n\nPlease review the log at ${LOGFILE}"
  echo msg
  notify-send -u critical -t 0 -i "${ICON_ERROR}" "VPN Configuration Failed" "${msg}"
  exit $exit_code

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

function tailscale_status() {
  if [ "$SHOW_VPN_STAT" == "1" ]; then
    tailscale_status=$(tailscale status)
    notify-send -u critical -t 0 -i "${ICON_SUCCESS}" "Tailscale Status" "${tailscale_status}"
  fi
}

function ip_status(){
  if [ "$SHOW_IP_STAT" == "1" ]; then
    ip_status=$(curl https://ipinfo.io/json)
    notify-send -u critical -t 0 -i "${ICON_SUCCESS}" "Public IP Status" "${ip_status}"
  fi
}

function process_tailscale(){

  local tailscale_key=$1

  if [ ! -c /dev/net/tun ]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
  fi
  tailscaled &
  sleep 2
  set +e
  tailscale up --authkey=${tailscale_key}
  if [ $? -ne 0 ]; then
      msg="Failed to establish tailscale connection. Please review the log at ${LOGFILE}"
      echo msg
      notify-send -u critical -t 0 -i "${ICON_ERROR}" "VPN Configuration Failed" "${msg}"
      exit 1
  fi
  set -e

  notify-send -u critical -t 0 -i "${ICON_SUCCESS}" "VPN Connected!" "Tailscale VPN Connected Successfully"
  tailscale_status
  ip_status
  cleanup_log
  exit 0
}


function openvpn_status() {
  if [ "$SHOW_VPN_STAT" == "1" ]; then
    openvpn_status=$(cat ${OPENVPN_STATUS_LOG})
    notify-send -u critical -t 0 -i "${ICON_SUCCESS}" "OpenVPN Status" "${openvpn_status}"
  fi
}


function process_openvpn() {
  local openvpn_config=$1

   # Create tun device
  if [ ! -c /dev/net/tun ]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
  fi
  if which resolvconf; then
    openvpn --pull-filter ignore route-ipv6 --pull-filter ignore ifconfig-ipv6 --config "${openvpn_config}" --status ${OPENVPN_STATUS_LOG} &
    sleep 10
    if ! pgrep openvpn; then
      msg="An error has occurred starting the VPN please review the log at ${LOGFILE}"
      echo msg
      notify-send -u critical -t 0 -i "${ICON_ERROR}" "VPN Configuration Failed" "${msg}"
      exit 1
    else
      notify-send -u critical -t 0 -i "${ICON_SUCCESS}" "VPN Connected!" "OpenVPN Connected Successfully"
      openvpn_status
      ip_status
      cleanup_log
      exit 0
    fi
  else
    msg="Resolvconf is not found on this system this container is not compatible with OpenVPN"
    echo msg
    notify-send -u critical -t 0 -i "${ICON_ERROR}" "VPN Configuration Failed" "${msg}"
    exit 1
  fi
}

function wireguard_status() {
  if [ "$SHOW_VPN_STAT" == "1" ]; then
    wg_show=$(wg show)
    notify-send -u critical -t 0 -i "${ICON_SUCCESS}" "WireGuard Status" "${wg_show}"
  fi
}


function process_wireguard() {

  local wireguard_conf=$1
  echo "WireGuard config detected checking for support"
  if ip link add dev test type wireguard; then
    echo "WireGuard kernel module is present on this host continuing"
    ip link del dev test
  else
    msg="WireGuard kernel module is not present on this host and a WireGuard config was passed will not continue"
    echo msg
    notify-send -u critical -t 0 -i "${ICON_ERROR}" "VPN Configuration Failed" "${msg}"
    exit 1
  fi

  wg-quick up ${wireguard_conf}
  if [ $? -ne 0 ]; then
      msg="Failed to establish WireGuard connection. Please review the log at ${LOGFILE}"
      echo msg
      notify-send -u critical -t 0 -i "${ICON_ERROR}" "VPN Configuration Failed" "${msg}"
      exit 1
  fi
  notify-send -u critical -t 0 -i "${ICON_SUCCESS}" "VPN Connected!" "WireGuard VPN Connected Successfully"
  wireguard_status
  ip_status
  cleanup_log
  exit 0

}

notify-send -u critical -t 0  -i "${ICON_OFFLINE}" "Connecting to VPN" "Please wait while the VPN connection is being established..."

VPN_LAUNCH_CONFIG='/dockerstartup/launch_selections.json'
# Launch Config Based Workflow
if [ -e ${VPN_LAUNCH_CONFIG} ]; then

  VPN_SERVICE="$(jq -r '.vpn_service' ${VPN_LAUNCH_CONFIG})"

  if [ "${VPN_SERVICE}" == "tailscale" ]; then
    ts_key="$(jq -r '.tailscale_key' ${VPN_LAUNCH_CONFIG})"
    process_tailscale $ts_key

  elif [ "${VPN_SERVICE}" == "openvpn" ]; then
    OPENVPN_USERNAME="$(jq -r '.openvpn_username' ${VPN_LAUNCH_CONFIG})"
    OPENVPN_PASSWORD="$(jq -r '.openvpn_password' ${VPN_LAUNCH_CONFIG})"
    echo ${OPENVPN_USERNAME} > ${DEFAULT_OPENVPN_CREDS}
    echo ${OPENVPN_PASSWORD} >> ${DEFAULT_OPENVPN_CREDS}
    jq -r '.openvpn_config' ${VPN_LAUNCH_CONFIG} > ${DEFAULT_OPENVPN_CONFIG}
    sed -i "s#auth-user-pass#auth-user-pass ${DEFAULT_OPENVPN_CREDS}#g" ${DEFAULT_OPENVPN_CONFIG}
    process_openvpn $DEFAULT_OPENVPN_CONFIG

  elif [ "${VPN_SERVICE}" == "wireguard" ]; then
    jq -r '.wireguard_config' ${VPN_LAUNCH_CONFIG} > /dockerstartup/wireguard.conf
    process_wireguard "/dockerstartup/wireguard.conf"
  else
    notify-send -u critical -t 0 -i "${ICON_ERROR}" "VPN Configuration Failed" "Unknown or missing vpn_service"
    exit 1
  fi

else

# File-Mapping/Env Based Workflow

  ### Tailscale ###
  if [ "${TAILSCALE_KEY:0:5}" == "tskey" ]; then
    process_tailscale $TAILSCALE_KEY

  ### WireGuard ###
  elif [ -e ${DEFAULT_WIREGUARD_CONFIG} ]; then
    process_wireguard $DEFAULT_WIREGUARD_CONFIG

  ### OpenVPN ###
  elif [ -e ${DEFAULT_OPENVPN_CONFIG} ]; then
    VPN_CONFIG=$DEFAULT_OPENVPN_CONFIG
    # Check if we need user credentials
    if grep -x auth-user-pass ${VPN_CONFIG}; then
      get_set_creds
    fi
    process_openvpn $VPN_CONFIG

  else
    msg="VPN Config File or TAILSCALE_KEY is not defined"
    echo msg
    notify-send -u critical -t 0 -i "${ICON_ERROR}" "VPN Configuration Failed" "${msg}"
    exit 1
  fi
fi
