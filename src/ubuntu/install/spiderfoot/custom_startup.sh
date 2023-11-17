#!/usr/bin/env bash
set -ex
START_COMMAND="firefox"
PGREP="firefox"
export MAXIMIZE="false"
export MAXIMIZE_NAME="Mozilla Firefox"
MAXIMIZE_SCRIPT=$STARTUPDIR/maximize_window.sh
DEFAULT_FIREFOX_ARGS=""
FIREFOX_ARGS=${FIREFOX_APP_ARGS:-$DEFAULT_FIREFOX_ARGS}

SPIDERFOOT_SERVER="127.0.0.1:5002"
DEFAULT_SPIDERFOOT_ARGS="-l $SPIDERFOOT_SERVER"
SPIDERFOOT_ARGS=${SPIDERFOOT_APP_ARGS:-$DEFAULT_SPIDERFOOT_ARGS}

options=$(getopt -o gau: -l go,assign,url: -n "$0" -- "$@") || exit
eval set -- "$options"

while [[ $1 != -- ]]; do
    case $1 in
        -g|--go) GO='true'; shift 1;;
        -a|--assign) ASSIGN='true'; shift 1;;
        -u|--url) OPT_URL=$2; shift 2;;
        *) echo "bad option: $1" >&2; exit 1;;
    esac
done
shift

# Process non-option arguments.
for arg; do
    echo "arg! $arg"
done

FORCE=$2

# run with vgl if GPU is available
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "${KASM_EGL_CARD}" ] && [ ! -z "${KASM_RENDERD}" ] && [ -O "${KASM_RENDERD}" ] && [ -O "${KASM_EGL_CARD}" ] ; then
    START_COMMAND="/opt/VirtualGL/bin/vglrun -d ${KASM_EGL_CARD} $START_COMMAND"
fi

check_web_server() {
    curl -s -o /dev/null http://$SPIDERFOOT_SERVER && return 0 || return 1
}

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
                cd $HOME/spiderfoot/spiderfoot-4.0/
                xfce4-terminal -x python3 sf.py $SPIDERFOOT_ARGS &
                while ! check_web_server; do
                    sleep 1
                done
                set +e
                bash ${MAXIMIZE_SCRIPT} &
                $START_COMMAND $FIREFOX_ARGS $URL
                set -e
            fi
            sleep 1
        done
        set -x

    fi
}

kasm_startup
