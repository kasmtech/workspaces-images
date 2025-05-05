#!/usr/bin/env bash
set -ex
START_COMMAND="/opt/nessus/sbin/nessusd start"
PGREP="nessusd"
DEFAULT_ARGS=""
ARGS=${APP_ARGS:-$DEFAULT_ARGS}

FORCE=$2

kasm_startup() {
    if [ -n "$KASM_URL" ] ; then
        URL=$KASM_URL
    elif [ -z "$URL" ] ; then
        URL=$LAUNCH_URL
    fi

    if [ -z "$DISABLE_CUSTOM_STARTUP" ] ||  [ -n "$FORCE" ] ; then

        echo "Entering process startup loop"
        set +x
        while true
        do
            if ! pgrep -x $PGREP > /dev/null
            then
                /usr/bin/filter_ready
                /usr/bin/desktop_ready
                set +e
                bash ${MAXIMIZE_SCRIPT} &
                $START_COMMAND $ARGS $URL &
                sleep 3
                chromium-browser https://localhost:8834 --start-maximized &
                set -e
            fi
            sleep 1
        done
        set -x
    
    fi

} 

kasm_startup
