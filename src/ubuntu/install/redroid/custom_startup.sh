#!/usr/bin/env bash
set -ex
START_COMMAND="/usr/bin/supervisord"
DOCKER_PGREP="supervisord"
SCRCPY_PGREP="scrcpy"
DEFAULT_ARGS="-n"
ARGS=${APP_ARGS:-$DEFAULT_ARGS}
ANDROID_VERSION=${ANDROID_VERSION:-"13.0.0"}
REDROID_GPU_GUEST_MODE=${REDROID_GPU_GUEST_MODE:-"guest"}
REDROID_FPS=${REDROID_FPS:-"30"}
REDROID_WIDTH=${REDROID_WIDTH:-"720"}
REDROID_HEIGHT=${REDROID_HEIGHT:-"1280"}
REDROID_DPI=${REDROID_DPI:-"320"}
REDROID_SHOW_CONSOLE=${REDROID_SHOW_CONSOLE:-"1"}
REDROID_DISABLE_AUTOSTART=${REDROID_DISABLE_AUTOSTART:-"0"}
REDROID_DISABLE_HOST_CHECKS=${REDROID_DISABLE_HOST_CHECKS:-"0"}

ICON_ERROR="/usr/share/icons/ubuntu-mono-dark/status/22/system-devices-panel-alert.svg"


LAUNCH_CONFIG='/dockerstartup/redroid_launch_selections.json'
# Launch Config Based Workflow
if [ -e ${LAUNCH_CONFIG} ]; then
  ANDROID_VERSION="$(jq -r '.android_version' ${LAUNCH_CONFIG})"
fi


function check_modules() {
  if lsmod | grep -q binder_linux; then
    echo "binder_linux module is loaded."
  else
      msg="Host level module binder_linux is not loaded. Cannot continue.\nSee https://github.com/remote-android/redroid-doc?tab=readme-ov-file#getting-started for more details."
      echo msg
      notify-send -u critical -t 0 -i "${ICON_ERROR}" "Redroid Error" "${msg}"
      exit 1
  fi
}

start_android() {
  sleep 5
  xfce4-terminal --hide-menubar --command "bash -c \"sudo docker pull redroid/redroid:${ANDROID_VERSION}-latest \""
  sudo docker run -itd --rm --privileged \
    --pull always \
    -v ~/data:/data \
    -p 5555:5555 \
    redroid/redroid:${ANDROID_VERSION}-latest \
    androidboot.redroid_gpu_mode=${REDROID_GPU_GUEST_MODE} \
    androidboot.redroid_fps=${REDROID_FPS} \
    androidboot.redroid_width=${REDROID_WIDTH} \
    androidboot.redroid_height=${REDROID_HEIGHT} \
    androidboot.redroid_dpi=${REDROID_DPI}
    sleep 2
    adb connect localhost:5555
    sleep 5
}

start_scrcpy() {

  if [ "$REDROID_SHOW_CONSOLE" == "1" ]; then
    xfce4-terminal --hide-menubar --command "bash -c \"scrcpy --audio-codec=aac -s localhost:5555 --shortcut-mod=lalt --print-fps --max-fps=${REDROID_FPS} \"" &
  else
    scrcpy --audio-codec=aac -s localhost:5555 --shortcut-mod=lalt --print-fps --max-fps=${REDROID_FPS}
  fi

  wait_for_process $SCRCPY_PGREP
}

wait_for_process() {
  process_match=$1
  timeout=60
  interval=1
  elapsed_time=0

  echo "Waiting for $process_match..."
  while [[ $elapsed_time -lt $timeout ]]; do
      if pgrep -x $process_match > /dev/null; then
          echo "$process_match is running, continuing..."
          break
      fi
      sleep $interval
      elapsed_time=$((elapsed_time + interval))
  done

  if ! pgrep -x $process_match > /dev/null
  then
      echo "Did not find process $process_match"
  fi

}

kasm_startup() {
    if [ -n "$KASM_URL" ] ; then
        URL=$KASM_URL
    elif [ -z "$URL" ] ; then
        URL=$LAUNCH_URL
    fi

    if  [ -z "$DISABLE_CUSTOM_STARTUP" ] ||  [ -n "$FORCE" ]  ; then

        echo "Entering process startup loop"
        set +x
        while true
        do
            if ! pgrep -x $DOCKER_PGREP > /dev/null
            then
                set +e
                sudo /usr/bin/supervisord -n &
                set -e
                if [ "$REDROID_DISABLE_AUTOSTART" == "0" ]; then
                  start_android
                fi
            fi
            if [ "$REDROID_DISABLE_AUTOSTART" == "0" ]; then
                  if ! pgrep -x $SCRCPY_PGREP > /dev/null
                  then
                      start_scrcpy
                  fi
            fi
            sleep 1
        done
        set -x
    
    fi

} 

/usr/bin/filter_ready
/usr/bin/desktop_ready


if [ "$REDROID_DISABLE_HOST_CHECKS" == "0" ]; then
  check_modules
fi
kasm_startup
