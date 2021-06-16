#!/usr/bin/env bash
set -ex
FORCE=$1

DEFAULT_ARGS="-f localhost "
ARGS=${APP_ARGS:-$DEFAULT_ARGS}

if ( [ -z "$DISABLE_CUSTOM_STARTUP" ] ||  [ -n "$FORCE" ] ) ; then
    if [ -f /tmp/custom_startup.lck ] ; then
        echo "custom_startup already running!"
        exit 1
    fi
    touch /tmp/custom_startup.lck
    while true
    do
        if ! pgrep -x rdesktop > /dev/null
        then
            cd $HOME
            /usr/bin/desktop_ready
            /usr/bin/filter_ready
            set +e
            rdesktop $ARGS
            set -e
        fi
        sleep 1
    done
    rm /tmp/custom_startup.lck
fi