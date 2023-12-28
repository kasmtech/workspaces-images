#!/usr/bin/env bash
set -ex
START_COMMAND="/usr/bin/supervisord"
DOCKER_PGREP="supervisord"
SCRCPY_PGREP="scrcpy"
DEFAULT_ARGS="-n"
ARGS=${APP_ARGS:-$DEFAULT_ARGS}
ANDROID_VERSION=${ANDROID_VERSION:-"13.0.0"}
REDROID_GPU_GUEST_MODE=${REDROID_GPU_GUEST_MODE:-"guest"}
REDROID_FPS=${REDROID_FPS:-"60"}
REDROID_WIDTH=${REDROID_WIDTH:-"720"}
REDROID_HEIGHT=${REDROID_HEIGHT:-"1280"}
REDROID_DPI=${REDROID_DPI:-"320"}
REDROID_SHOW_CONSOLE=${REDROID_SHOW_CONSOLE:-"1"}

LAUNCH_CONFIG='/dockerstartup/redroid_launch_selections.json'
# Launch Config Based Workflow
if [ -e ${LAUNCH_CONFIG} ]; then
  ANDROID_VERSION="$(jq -r '.android_version' ${LAUNCH_CONFIG})"
fi

function audio_patch() {
  # The devices start with audio quite low
  set +e
    for ((i=1; i<=10; i++)); do
      adb -s localhost:5555 shell input keyevent KEYCODE_VOLUME_UP &
      sleep 0.2
    done
  set -e

}

start_android() {
  /usr/bin/filter_ready
  /usr/bin/desktop_ready
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
    audio_patch
}
start_scrcpy() {

  if [ "$REDROID_SHOW_CONSOLE" == "1" ]; then
    xfce4-terminal --hide-menubar --command "bash -c \"scrcpy --audio-codec=aac -s localhost:5555 --shortcut-mod=lalt --print-fps --max-fps=${REDROID_FPS} \"" &
  else
    scrcpy --audio-codec=aac -s localhost:5555 --shortcut-mod=lalt --print-fps --max-fps=${REDROID_FPS}
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
                /usr/bin/filter_ready
                /usr/bin/desktop_ready
                set +e
                sudo /usr/bin/supervisord -n &
                set -e
                start_android
            fi
            if ! pgrep -x $SCRCPY_PGREP > /dev/null
            then
                /usr/bin/filter_ready
                /usr/bin/desktop_ready
                start_scrcpy
            fi
            sleep 1
        done
        set -x
    
    fi

} 

kasm_startup
