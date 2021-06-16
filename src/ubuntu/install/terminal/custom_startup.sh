#!/usr/bin/env bash
set -ex
FORCE=$2
if [ -n "$1" ] ; then
    URL=$1
else
    URL=$LAUNCH_URL
fi

DEFAULT_ARGS="--fullscreen --hide-borders --hide-menubar --zoom=-1 --hide-scrollbar"
ARGS=${TERMINAL_ARGS:-$DEFAULT_ARGS}

if ( [ -z "$DISABLE_CUSTOM_STARTUP" ] ||  [ -n "$FORCE" ] ) ; then
    if [ -f /tmp/custom_startup.lck ] ; then
        echo "custom_startup already running!"
        exit 1
    fi
    touch /tmp/custom_startup.lck
    while true
    do
        if ! pgrep -x xfce4-terminal > /dev/null
        then
            cd $HOME
            /usr/bin/desktop_ready
            set +e
            xfce4-terminal  $ARGS
            set -e
        fi
        sleep 1
    done
    rm /tmp/custom_startup.lck
fi