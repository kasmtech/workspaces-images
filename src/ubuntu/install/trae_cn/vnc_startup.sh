#!/bin/bash
### every exit != 0 fails the script
set -e

APP_NAME=$(basename "$0")

log () {
    if [ ! -z "${1}" ]; then
        LOG_LEVEL="${2:-DEBUG}"
        INGEST_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${INGEST_DATE} ${LOG_LEVEL} (${APP_NAME}): $1"
        if [ ! -z "${KASM_API_JWT}" ]  && [ ! -z "${KASM_API_HOST}" ]  && [ ! -z "${KASM_API_PORT}" ]; then
            set +e
            http_proxy="" https_proxy="" curl https://${KASM_API_HOST}:${KASM_API_PORT}/api/kasm_session_log?token=${KASM_API_JWT} --max-time 1 -X POST -H 'Content-Type: application/json' -d '[{ "host": "'"${KASM_ID}"'", "application": "Session", "ingest_date": "'"${INGEST_DATE}"'", "message": "'"$1"'", "levelname": "'"${LOG_LEVEL}"'", "process": "'"${APP_NAME}"'", "kasm_user_name": "'"kasm_user"'", "kasm_id": "'"${KASM_ID}"'" }]' -k -s
            set -e
        fi
    fi
}

no_proxy="localhost,127.0.0.1"

if [ -f /usr/bin/kasm-profile-sync ] && [ -f /usr/bin/kasm-profile-sync-2 ]; then
        kasm_profile_sync_found=1
fi

# Set lang values
if [ -n "${LC_ALL}" ]; then
  export LANG=${LC_ALL}
  export LANGUAGE=${LC_ALL}
elif [ -n "${LANG}" ]; then
  export LC_ALL=${LANG}
  export LANGUAGE=${LANG}
fi

# Set timezone from TZ environment variable
if [ -n "${TZ}" ]; then
  ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
  echo "${TZ}" > /etc/timezone
fi

# Dbus
export $(dbus-launch)

# dict to store processes
declare -A KASM_PROCS

# switch passwords to local variables
tmpval=$VNC_VIEW_ONLY_PW
unset VNC_VIEW_ONLY_PW
VNC_VIEW_ONLY_PW=$tmpval
tmpval=$VNC_PW
unset VNC_PW
VNC_PW=$tmpval

BUILD_ARCH=$(uname -p)
if [ -z ${KASM_PROFILE_CHUNK_SIZE} ]; then
  KASM_PROFILE_CHUNK_SIZE=100000
fi
if [ -z ${DRINODE+x} ]; then
  DRINODE="/dev/dri/renderD128"
fi
KASMNVC_HW3D=''
if [ ! -z ${HW3D+x} ]; then
  KASMVNC_HW3D="-hw3d"
fi
STARTUP_COMPLETE=0

######## FUNCTION DECLARATIONS ##########

## print out help
function help (){
        echo "
                USAGE:

                OPTIONS:
                -w, --wait      (default) keeps the UI and the vncserver up until SIGINT or SIGTERM will received
                -s, --skip      skip the vnc startup and just execute the assigned command.
                                example: docker run kasmweb/core --skip bash
                -d, --debug     enables more detailed startup output
                                e.g. 'docker run kasmweb/core --debug bash'
                -h, --help      print out this help
                "
}

trap cleanup SIGINT SIGTERM SIGQUIT SIGHUP ERR

function pull_profile (){
        if [ ! -z "$KASM_PROFILE_LDR" ]; then
                if [ -z "$kasm_profile_sync_found" ]; then
                        echo >&2 "Profile sync not available"
                        sleep 3
                        http_proxy="" https_proxy="" curl -k "https://${KASM_API_HOST}:${KASM_API_PORT}/api/set_kasm_session_status?token=${KASM_API_JWT}" -H 'Content-Type: application/json' -d '{"status": "running"}'
                        return
                fi

                log "Downloading and unpacking user profile from object storage."
                set +e
                if [[ $DEBUG == true ]]; then
                        OUTPUT=$(http_proxy="" https_proxy="" /usr/bin/kasm-profile-sync --download /home/kasm-user --insecure --remote ${KASM_API_HOST} --port ${KASM_API_PORT} -c ${KASM_PROFILE_CHUNK_SIZE} --token ${KASM_API_JWT} --verbose 2>&1 )
                else
                        OUTPUT=$(http_proxy="" https_proxy="" /usr/bin/kasm-profile-sync --download /home/kasm-user --insecure --remote ${KASM_API_HOST} --port ${KASM_API_PORT} -c ${KASM_PROFILE_CHUNK_SIZE} --token ${KASM_API_JWT} 2>&1 )
                fi

                # log output of profile sync
                while IFS= read -r line; do
            log "$line"
        done <<< "$OUTPUT"

                # exit and log a non-zero exit code
                PROCESS_SYNC_EXIT_CODE=$?
                set -e
                if (( PROCESS_SYNC_EXIT_CODE > 1 )); then
                        log "Profile-sync failed with a non-recoverable error. See server side logs for more details." "ERROR"
                        exit 1
                fi
                log "Profile load complete."
                # Update the status of the container to running
                sleep 3
                http_proxy="" https_proxy="" curl -k "https://${KASM_API_HOST}:${KASM_API_PORT}/api/set_kasm_session_status?token=${KASM_API_JWT}" -H 'Content-Type: application/json' -d '{"status": "running"}'

                # Reset the timer to prevent session recording monitor from exiting
                SECONDS=0
        fi
}

function profile_size_check(){
        if [ ! -z "$KASM_PROFILE_SIZE_LIMIT" ]
        then
                SIZE_CHECK_FAILED=false
                while true
                do
                        sleep 60
                        CURRENT_SIZE=$(du -s $HOME | grep -Po '^\d+')
                        SIZE_LIMIT_MB=$(echo "$KASM_PROFILE_SIZE_LIMIT / 1000" | bc)
                        if [[ $CURRENT_SIZE -gt KASM_PROFILE_SIZE_LIMIT ]]
                        then
                                notify-send "Profile Size Exceeds Limit" "Your home profile has exceeded the size limit of ${SIZE_LIMIT_MB}MB. Changes on your desktop will not be saved between sessions until you reduce the size of your profile." -i /usr/share/icons/ubuntu-mono-dark/apps/22/dropboxstatus-x.svg -t 57000
                                SIZE_CHECK_FAILED=true
                        else
                                if [ "$SIZE_CHECK_FAILED" = true ] ; then
                                        SIZE_CHECK_FAILED=false
                                        notify-send "Profile Size" "Your home profile size is now under the limit and will be saved when your session is terminated." -i /usr/share/icons/ubuntu-mono-dark/apps/22/dropboxstatus-logo.svg -t 57000
                                fi
                        fi

                        if [ -f  /tmp/.kasm_container_shutdown_failure ]; then
                                notify-send "Profile Size" "Your profile failed to save. Contact your administrator for assistance." -i /usr/share/icons/ubuntu-mono-dark/apps/22/dropboxstatus-logo.svg -t 57000
                        fi
                done
        fi
}

## correct forwarding of shutdown signal
function cleanup () {
    kill -s SIGTERM $!
    exit 0
}

function start_kasmvnc (){
        log "Starting KasmVNC"

        DISPLAY_NUM=$(echo $DISPLAY | grep -Po ':\d+')

        if [[ $STARTUP_COMPLETE == 0 ]]; then
            vncserver -kill $DISPLAY &> $STARTUPDIR/vnc_startup.log \
            || rm -rfv /tmp/.X*-lock /tmp/.X11-unix &> $STARTUPDIR/vnc_startup.log \
            || echo "no locks present"
        fi

        rm -rf $HOME/.vnc/*.pid
        echo "exit 0" > $HOME/.vnc/xstartup
        chmod +x $HOME/.vnc/xstartup

        VNCOPTIONS="$VNCOPTIONS -select-de manual"

        if [[ ${KASM_SVC_PRINTER:-1} == 1 ]]; then
                VNCOPTIONS="$VNCOPTIONS -UnixRelay printer:/tmp/printer"
        fi

        if [[ ${BUILD_ARCH} =~ ^aarch64$ && -f /lib/aarch64-linux-gnu/libgcc_s.so.1 ]] ; then
                LD_PRELOAD=/lib/aarch64-linux-gnu/libgcc_s.so.1 vncserver $DISPLAY $KASMVNC_HW3D -drinode $DRINODE -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION -websocketPort $NO_VNC_PORT -httpd ${KASM_VNC_PATH}/www -sslOnly -FrameRate=$MAX_FRAME_RATE -interface 0.0.0.0 -BlacklistThreshold=0 -FreeKeyMappings $VNCOPTIONS $KASM_SVC_SEND_CUT_TEXT $KASM_SVC_ACCEPT_CUT_TEXT
        else
                vncserver $DISPLAY $KASMVNC_HW3D -drinode $DRINODE -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION -websocketPort $NO_VNC_PORT -httpd ${KASM_VNC_PATH}/www -sslOnly -FrameRate=$MAX_FRAME_RATE -interface 0.0.0.0 -BlacklistThreshold=0 -FreeKeyMappings $VNCOPTIONS $KASM_SVC_SEND_CUT_TEXT $KASM_SVC_ACCEPT_CUT_TEXT
        fi

        KASM_PROCS['kasmvnc']=$(cat $HOME/.vnc/*${DISPLAY_NUM}.pid)

        #Disable X11 Screensaver
        if [ "${DISTRO}" != "alpine" ]; then
                echo "Disabling X Screensaver Functionality"
                xset -dpms || true
                xset s off || true
                xset q || true
        else
                echo "Disabling of X Screensaver Functionality for $DISTRO is not required."
        fi

        if [[ $DEBUG == true ]]; then
          echo -e "\n------------------ Started Websockify  ----------------------------"
          echo "Websockify PID: ${KASM_PROCS['kasmvnc']}";
        fi
}

function start_window_manager (){
        echo -e "\n------------------ Xfce4 window manager startup------------------"
        if [ "${START_XFCE4}" == "1" ] || [ "${START_DE}" == "xfce4-session" ]; then
                if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "${KASM_EGL_CARD}" ] && [ ! -z "${KASM_RENDERD}" ] && [ -O "${KASM_RENDERD}" ] && [ -O "${KASM_EGL_CARD}" ] ; then
                echo "Starting XFCE with VirtualGL using EGL device ${KASM_EGL_CARD}"
                        DISPLAY=:1 /opt/VirtualGL/bin/vglrun -d "${KASM_EGL_CARD}" /usr/bin/startxfce4 --replace &
                else
                        echo "Starting XFCE"
                        DISPLAY=:1 /usr/bin/startxfce4 --replace &
                fi
                KASM_PROCS['window_manager']=$!
        else
                echo "Skipping XFCE Startup"
        fi
        echo -e "\n------------------ Openbox window manager startup------------------"
        if [ "${START_DE}" == "openbox" ] ; then
                /usr/bin/openbox-session &
                KASM_PROCS['window_manager']=$!
        else
                echo "Skipping OpenBox Startup"
        fi
        echo -e "\n------------------ KDE window manager startup------------------"
        if [ "${START_DE}" == "kde5" ] ; then
                if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "${KASM_EGL_CARD}" ] && [ ! -z "${KASM_RENDERD}" ] && [ -O "${KASM_RENDERD}" ] && [ -O "${KASM_EGL_CARD}" ] ; then
                echo "Starting KDE with VirtualGL using EGL device ${KASM_EGL_CARD}"
                        DISPLAY=:1 /opt/VirtualGL/bin/vglrun -d "${KASM_EGL_CARD}" /usr/bin/startplasma-x11 &
                else
                        echo "Starting KDE"
                        DISPLAY=:1 /usr/bin/startplasma-x11 &
                fi
                KASM_PROCS['window_manager']=$!
        else
                echo "Skipping KDE Startup"
        fi
}

function start_audio_out_websocket (){
        if [[ ${KASM_SVC_AUDIO:-1} == 1 ]]; then
                log 'Starting audio websocket server'
                $STARTUPDIR/jsmpeg/kasm_audio_out-linux kasmaudio 8081 4901 ${HOME}/.vnc/self.pem ${HOME}/.vnc/self.pem "${KASM_USER}:$VNC_PW" &

                KASM_PROCS['kasm_audio_out_websocket']=$!

                if [[ $DEBUG == true ]]; then
                  echo -e "\n------------------ Started Audio Out Websocket  ----------------------------"
                  echo "Kasm Audio Out Websocket PID: ${KASM_PROCS['kasm_audio_out_websocket']}";
                fi
        fi
}

function start_audio_out (){
        if [[ ${KASM_SVC_AUDIO:-1} == 1 ]]; then
                log 'Starting audio server'

        if [ "${START_PULSEAUDIO:-0}" == "1" ] ;
        then
            echo "Starting Pulse"
            HOME=/var/run/pulse pulseaudio --start
        fi

                if [[ $DEBUG == true ]]; then
                        echo 'Starting audio service in debug mode'
                        HOME=/var/run/pulse no_proxy=127.0.0.1 ffmpeg -v verbose -f pulse -fragment_size ${PULSEAUDIO_FRAGMENT_SIZE:-2000} -ar 44100 -i default -f mpegts -correct_ts_overflow 0 -codec:a mp2 -b:a 128k -ac 1 -muxdelay 0.001 http://127.0.0.1:8081/kasmaudio &
                        KASM_PROCS['kasm_audio_out']=$!
                else
                        echo 'Starting audio service'
                        HOME=/var/run/pulse no_proxy=127.0.0.1 ffmpeg -f pulse -fragment_size ${PULSEAUDIO_FRAGMENT_SIZE:-2000} -ar 44100 -i default -f mpegts -correct_ts_overflow 0 -codec:a mp2 -b:a 128k -ac 1 -muxdelay 0.001 http://127.0.0.1:8081/kasmaudio > /dev/null 2>&1 &
                        KASM_PROCS['kasm_audio_out']=$!
                        echo -e "\n------------------ Started Audio Out  ----------------------------"
                        echo "Kasm Audio Out PID: ${KASM_PROCS['kasm_audio_out']}";
                fi
        fi
}

function start_audio_in (){
        if [[ ${KASM_SVC_AUDIO_INPUT:-1} == 1 ]]; then
                log 'Starting audio input server'
                $STARTUPDIR/audio_input/kasm_audio_input_server --ssl --auth-token "${KASM_USER}:$VNC_PW" --cert ${HOME}/.vnc/self.pem --certkey ${HOME}/.vnc/self.pem &

                KASM_PROCS['kasm_audio_in']=$!

                if [[ $DEBUG == true ]]; then
                        echo -e "\n------------------ Started Audio Out Websocket  ----------------------------"
                        echo "Kasm Audio In PID: ${KASM_PROCS['kasm_audio_in']}";
                fi
        fi
}

function start_upload (){
        if [[ ${KASM_SVC_UPLOADS:-1} == 1 ]]; then
                log 'Starting upload server'
                $STARTUPDIR/upload_server/kasm_upload_server --ssl --auth-token "${KASM_USER}:$VNC_PW" --port 4902 --upload_dir ${HOME}/Uploads &

                KASM_PROCS['upload_server']=$!

                if [[ $DEBUG == true ]]; then
                        echo -e "\n------------------ Started Upload Server  ----------------------------"
                        echo "Upload Server PID: ${KASM_PROCS['upload_server']}";
                fi
        fi
}

function start_gamepad (){
        if [[ ${KASM_SVC_GAMEPAD:-1} == 1 ]]; then
                log 'Starting gamepad server'
                $STARTUPDIR/gamepad/kasm_gamepad_server --ssl --auth-token "${KASM_USER}:$VNC_PW" --cert ${HOME}/.vnc/self.pem --certkey ${HOME}/.vnc/self.pem &

                KASM_PROCS['kasm_gamepad']=$!

                if [[ $DEBUG == true ]]; then
                        echo -e "\n------------------ Started Gamepad Websocket  ----------------------------"
                        echo "Kasm Gamepad PID: ${KASM_PROCS['kasm_gamepad']}";
                fi
        fi
}

function start_webcam (){
        if [[ ${KASM_SVC_WEBCAM:-1} == 1 ]] && [[ -e /dev/video0 ]]; then
                log 'Starting webcam server'
                if [[ $DEBUG == true ]]; then
                        $STARTUPDIR/webcam/kasm_webcam_server --debug --port 4905 --ssl --cert ${HOME}/.vnc/self.pem --certkey ${HOME}/.vnc/self.pem &
                else
                        $STARTUPDIR/webcam/kasm_webcam_server --port 4905 --ssl --cert ${HOME}/.vnc/self.pem --certkey ${HOME}/.vnc/self.pem &
                fi

                KASM_PROCS['kasm_webcam']=$!

                if [[ $DEBUG == true ]]; then
                        echo -e "\n------------------ Started Webcam Websocket  ----------------------------"
                        echo "Kasm Webcam PID: ${KASM_PROCS['kasm_webcam']}";
                fi
        fi
}

function start_printer (){
                if [[ ${KASM_SVC_PRINTER:-1} == 1 ]]; then
                        log 'Starting printer service'
            if [[ $DEBUG == true ]]; then
                            $STARTUPDIR/printer/kasm_printer_service --debug --directory $HOME/PDF --relay /tmp/printer &
                    else
                            $STARTUPDIR/printer/kasm_printer_service --directory $HOME/PDF --relay /tmp/printer &
                    fi

                KASM_PROCS['kasm_printer']=$!

                if [[ $DEBUG == true ]]; then
                        echo -e "\n------------------ Started Printer Service  ----------------------------"
                        echo "Kasm Printer PID: ${KASM_PROCS['kasm_printer']}";
                fi
        fi
}

function wait_on_printer (){
    # Wait for cups and the printer device to be created
    if [[ ${KASM_SVC_PRINTER:-1} == 1 && ${KASM_PRINTER_WAIT:-0} == 1 ]]; then
        log 'Waiting on printer service to be ready'
        /usr/bin/printer_ready
        log 'Printer is ready'
    fi
}


function custom_startup (){
        custom_startup_script=/dockerstartup/custom_startup.sh
        if [ -f "$custom_startup_script" ]; then
                if [ ! -x "$custom_startup_script" ]; then
                        echo "${custom_startup_script}: not executable, exiting"
                        exit 1
                fi

                "$custom_startup_script" &
                KASM_PROCS['custom_startup']=$!
                log "Executed custom startup script."
        fi
}

function ensure_recorder_running () {
    if [[ ${KASM_SVC_RECORDER:-0} != 1 ]]; then
        return
    fi

    local kasm_recorder_process="/dockerstartup/recorder/kasm_recorder_service"
    local kasm_recorder_ack="/tmp/kasm_recorder.ack"

        if [[ -f "$kasm_recorder_ack" ]]; then
        local ack_user=$(stat -c '%U' $kasm_recorder_ack)
        if [[ "$ack_user" == "kasm-recorder" ]]; then
            SECONDS=0  #SECONDS is a built in bash variable that is incremented approximately every second
            kasm_recorder_pid=""
        fi
    fi

    local recorder_pid=$(pgrep -f "^$kasm_recorder_process") || true

    if [[ -z $kasm_recorder_pid ]]; then
        # This leverages the outside while loop that calls this function to provider checking ever x seconds.
        if [[ -z $recorder_pid ]] && (( $SECONDS > 15 )); then
            log "$kasm_recorder_process: not started, exiting" "ERROR"
            exit 0
        fi

        kasm_recorder_pid=$recorder_pid
    else
        if [[ -z $recorder_pid ]]; then
            log "$kasm_recorder_process: not running, exiting" "ERROR"
            exit 0
        fi

        recorder_user=$(ps -p $recorder_pid -o user=)
        if [[ $recorder_user != "kasm-recorder" ]]; then
            log "$kasm_recorder_process: not running as kasm-recorder, exiting" "ERROR"
            exit 0
        fi
    fi
}

function ensure_recorder_terminates_gracefully () {
  local kasm_recorder_process="/dockerstartup/recorder/kasm_recorder_service"

  while true
  do
    recorder_pid=$(pgrep -f "$kasm_recorder_process") || true
    if [[ -z $recorder_pid ]]; then
      break
    fi

    sleep 1
  done
}

function wait_for_egress_signal() {
        egress_file="/dockerstartup/.egress_status"

        while [ ! -f "$egress_file" ]; do
                sleep 1
        done

        egress_status=$(cat $egress_file)

        if [ "$egress_status" == "ready" ]; then
                return
        fi

        if [ "$egress_status" == "error" ]; then
                echo "Failed to establish egress gateway. Exiting..."
                exit 0
        fi
}

function wait_for_network_devices() {
        while true; do
                interfaces=$(ip -o link show | awk '!/lo:/ && !/tun/' | awk -F: '/^[0-9]+: / {print $2}' | awk '{print $1}' | sed 's/@.*//')
                if [ -z "$interfaces" ]; then
                        sleep 1
                        continue
                fi

                for interface in $interfaces; do
                        # ignore eth* interfaces if egress gateway is enabled
                        if [[ $interface == eth* && -z $KASM_SVC_EGRESS ]]; then
                                        return
                        fi

                        if [[ $interface == k-p-* ]]; then
                                wait_for_egress_signal

                                if [ -z "$KASM_PROFILE_LDR" ]; then
                                        http_proxy="" https_proxy="" curl -k "https://${KASM_API_HOST}:${KASM_API_PORT}/api/set_kasm_session_status?token=${KASM_API_JWT}" -H 'Content-Type: application/json' -d '{"status": "running"}'
                                fi

                                return
                        fi
                done

                sleep 1
        done
}

############ END FUNCTION DECLARATIONS ###########

if [[ $1 =~ -h|--help ]]; then
    help
    exit 0
fi

if [[ ${KASM_DEBUG:-0} == 1 ]]; then
    echo -e "\n\n------------------ DEBUG KASM STARTUP -----------------"
    export DEBUG=true
    set -x
fi

# wait for any network interface other than loopback to be up
# this is necessary because containers with egress gateways
# have a custom network interface setup that might not be ready
wait_for_network_devices

# Syncronize user-space loaded persistent profiles
pull_profile

# should also source $STARTUPDIR/generate_container_user
if [ -f $HOME/.bashrc ]; then
    source $HOME/.bashrc
fi

## resolve_vnc_connection
VNC_IP=$(hostname -i)
if [[ $DEBUG == true ]]; then
    echo "IP Address used for external bind: $VNC_IP"
fi

# Create cert for KasmVNC
mkdir -p ${HOME}/.vnc
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout ${HOME}/.vnc/self.pem -out ${HOME}/.vnc/self.pem -subj "/C=US/ST=VA/L=None/O=None/OU=DoFu/CN=kasm/emailAddress=none@none.none"

# first entry is control, second is view (if only one is valid for both)
mkdir -p "$HOME/.vnc"
PASSWD_PATH="$HOME/.kasmpasswd"
if [[ -f $PASSWD_PATH ]]; then
    echo -e "\n---------  purging existing VNC password settings  ---------"
    rm -f $PASSWD_PATH
fi

echo -e "${VNC_PW}\n${VNC_PW}\n" | kasmvncpasswd -u ${KASM_USER} -wo
echo -e "${VNC_PW}\n${VNC_PW}\n" | kasmvncpasswd -u kasm_viewer -r
chmod 600 $PASSWD_PATH


# start processes
wait_on_printer
start_kasmvnc
start_window_manager
start_audio_out_websocket
start_audio_out
start_audio_in
start_upload
# start_gamepad
profile_size_check &
# start_webcam
start_printer

STARTUP_COMPLETE=1


## log connect options
echo -e "\n\n------------------ KasmVNC environment started ------------------"

# tail vncserver logs
tail -f $HOME/.vnc/*$DISPLAY.log &

KASMIP=$(hostname -i)
log "Kasm User ${KASM_USER}(${KASM_USER_ID}) started container id ${HOSTNAME} with local IP address ${KASMIP}" "INFO"

# start custom startup script
custom_startup

# Monitor Kasm Services
sleep 3
while :
do
        for process in "${!KASM_PROCS[@]}"; do
                if ! kill -0 "${KASM_PROCS[$process]}" ; then

                        # If DLP Policy is set to fail secure, default is to be resilient
                        if [[ ${DLP_PROCESS_FAIL_SECURE:-0} == 1 ]]; then
                                log "DLP Policy violation, exiting container" "ERROR"
                                exit 1
                        fi

                        case $process in
                                kasmvnc)
                                        if [ "$KASMVNC_AUTO_RECOVER" = true ] ; then
                                                log "KasmVNC crashed, restarting" "WARNING"
                                                start_kasmvnc
                                        else
                                                log "KasmVNC crashed, exiting container" "ERROR"
                                                exit 1
                                        fi
                                        ;;
                                window_manager)
                                        log "Window manager crashed, restarting" "WARNING"

                                        if [[ ${KASM_SVC_RECORDER:-0} == 1 ]]; then
                                                log "Waiting for recorder service to upload all pending recordings"
                                                ensure_recorder_terminates_gracefully
                                                log "Recorder service has terminated, exiting container" "ERROR"
                                                exit 1
                                        fi

                                        start_window_manager
                                        ;;
                                kasm_audio_out_websocket)
                                        echo "Restarting Audio Out Websocket Service"
                                        start_audio_out_websocket
                                        ;;
                                kasm_audio_out)
                                        echo "Restarting Audio Out Service"
                                        start_audio_out
                                        ;;
                                kasm_audio_in)
                                        echo "Audio In Service Failed"
                                        # TODO: Needs work in python project to support auto restart
                                        # start_audio_in
                                        ;;
                                upload_server)
                                        echo "Restarting Upload Service"
                                        # TODO: This will only work if both processes are killed, requires more work
                                        start_upload
                                        ;;
                                kasm_gamepad)
                                        echo "Gamepad Service Failed"
                                        # TODO: Needs work in python project to support auto restart
                                        # start_gamepad
                                        ;;
                                kasm_webcam)
                                        echo "Webcam Service Failed"
                                        # TODO: Needs work in python project to support auto restart
                                        start_webcam
                                        ;;
                                kasm_printer)
                                        echo "Printer Service Failed"
                                        # TODO: Needs work in python project to support auto restart
                                        start_printer
                                        ;;
                                custom_script)
                                        echo "The custom startup script exited."
                                        # custom startup scripts track the target process on their own, they should not exit
                                        custom_startup
                                        ;;
                                *)
                                        echo "Unknown Service: $process"
                                        ;;
                        esac
                fi
        done

        ensure_recorder_running

        sleep 3
done


log "Exiting Kasm container"
