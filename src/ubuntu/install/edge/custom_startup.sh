#!/usr/bin/env bash
set -ex
FORCE=$2
if [ -n "$1" ] ; then
    URL=$1
else
    URL=$LAUNCH_URL
fi

DEFAULT_ARGS="--start-maximized"
ARGS=${APP_ARGS:-$DEFAULT_ARGS}


if [ -n "$URL" ] && ( [ -z "$DISABLE_CUSTOM_STARTUP" ] ||  [ -n "$FORCE" ] ) ; then
    if [ -f /tmp/custom_startup.lck ] ; then
        echo "custom_startup already running!"
        exit 1
    fi
    touch /tmp/custom_startup.lck
    while true
    do
        if ! pgrep -x msedge > /dev/null
        then
            /usr/bin/filter_ready
            /usr/bin/desktop_ready
            set +e
            microsoft-edge $ARGS $URL
            set -e
        fi
        sleep 1
    done
    rm /tmp/custom_startup.lck
fi