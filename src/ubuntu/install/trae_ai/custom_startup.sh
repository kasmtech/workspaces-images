#!/usr/bin/env bash
set -ex
START_COMMAND="trae-ai"

TRAE_WORKDIR=${TRAE_WORKDIR:-"/trae-ai"}
mkdir -p ${TRAE_WORKDIR}/trae
[[ -e ~/.trae ]] || ln -s ${TRAE_WORKDIR}/trae ~/.trae
mkdir -p ${TRAE_WORKDIR}/trae-ai
[[ -e ~/.trae-ai ]] || ln -s ${TRAE_WORKDIR}/trae-ai ~/.trae-ai
mkdir -p ${TRAE_WORKDIR}/trae-ai-server
[[ -e ~/.trae-ai-server ]] || ln -s ${TRAE_WORKDIR}/trae-ai-server ~/.trae-ai-server
mkdir -p ${TRAE_WORKDIR}/trae-aicc
[[ -e ~/.trae-aicc ]] || ln -s ${TRAE_WORKDIR}/trae-aicc ~/.trae-aicc
mkdir -p ${TRAE_WORKDIR}/config
[[ -e ~/.config ]] || ln -s ${TRAE_WORKDIR}/config ~/.config
mkdir -p ${TRAE_WORKDIR}/trae
[[ -e ~/.trae ]] || ln -s ${TRAE_WORKDIR}/trae ~/.trae
mkdir -p ${TRAE_WORKDIR}/user-data
USER_DATA_DIR=${TRAE_WORKDIR}/user-data
mkdir -p ${TRAE_WORKDIR}/extensions
EXTENSIONS_DIR=${TRAE_WORKDIR}/extensions
mkdir -p ${TRAE_WORKDIR}/workspace
WORKSPACE_DIR=${TRAE_WORKDIR}/workspace

if [[ $(id -u) == 0 ]]; then
    START_COMMAND="$START_COMMAND --no-sandbox"
fi

START_COMMAND="$START_COMMAND --user-data-dir=${USER_DATA_DIR} --extensions-dir=${EXTENSIONS_DIR} --add ${WORKSPACE_DIR}"

PGREP_PATTERN="/usr/share/trae/trae"
export MAXIMIZE="true"
export MAXIMIZE_NAME="Trae"
MAXIMIZE_SCRIPT=$STARTUPDIR/maximize_window.sh
DEFAULT_ARGS=""
ARGS=${APP_ARGS:-$DEFAULT_ARGS}

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

for arg; do
    echo "arg! $arg"
done

FORCE=$2

kasm_exec() {
    if [ -n "$OPT_URL" ] ; then
        URL=$OPT_URL
    elif [ -n "$1" ] ; then
        URL=$1
    fi

    if [ -n "$URL" ] ; then
        /usr/bin/filter_ready
        /usr/bin/desktop_ready
        bash ${MAXIMIZE_SCRIPT} &
        $START_COMMAND $ARGS "$URL"
    else
        echo "No URL specified for exec command. Doing nothing."
    fi
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
            if ! pgrep -f "$PGREP_PATTERN" > /dev/null
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

if [ -n "$GO" ] || [ -n "$ASSIGN" ] ; then
    kasm_exec
else
    kasm_startup
fi
