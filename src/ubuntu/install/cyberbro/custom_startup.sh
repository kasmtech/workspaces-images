#!/usr/bin/env bash
set -ex
START_COMMAND="cyberbro"
PGREP="firefox"
export MAXIMIZE="true"
export MAXIMIZE_NAME="Mozilla Firefox"
MAXIMIZE_SCRIPT=$STARTUPDIR/maximize_window.sh
DEFAULT_ARGS=""
ARGS=${APP_ARGS:-$DEFAULT_ARGS}


# Check if GUI_ENABLED_ENGINES is set else apply default
if [ -z ${GUI_ENABLED_ENGINES+x} ]; then
    # Add all engines by default
    GUI_ENABLED_ENGINES=""
fi

# Make GUI_ENABLED_ENGINES an environment variable
export GUI_ENABLED_ENGINES

# Process non-option arguments.
for arg; do
    echo "arg! $arg"
done

FORCE=$2

# run with vgl if GPU is available
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "${KASM_EGL_CARD}" ] && [ ! -z "${KASM_RENDERD}" ] && [ -O "${KASM_RENDERD}" ] && [ -O "${KASM_EGL_CARD}" ] ; then
    START_COMMAND="/opt/VirtualGL/bin/vglrun -d ${KASM_EGL_CARD} $START_COMMAND"
fi


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
                $START_COMMAND $ARGS $URL
                set -e
            fi
            sleep 1
        done
        set -x

    fi
}

kasm_startup