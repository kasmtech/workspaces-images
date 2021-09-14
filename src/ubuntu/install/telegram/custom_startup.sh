#!/usr/bin/env bash
set -ex
FORCE=$1

DEFAULT_ARGS=""
ARGS=${APP_ARGS:-$DEFAULT_ARGS}



if ( [ -z "$DISABLE_CUSTOM_STARTUP" ] ||  [ -n "$FORCE" ] ) ; then
    if [ -f /tmp/custom_startup.lck ] ; then
        echo "custom_startup already running!"
        exit 1
    fi
    touch /tmp/custom_startup.lck
    while true
    do
        if ! pgrep -x Telegram > /dev/null
        then
            /usr/bin/desktop_ready
            /usr/bin/filter_ready
            set +e
            /opt/Telegram/Telegram $ARGS &
            set -e
        fi
        sleep 1
    done
    rm /tmp/custom_startup.lck
fi