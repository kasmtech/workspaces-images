#!/usr/bin/env bash

# Coeadapt Agent startup script — keeps services running via respawn loop.
# Pattern matches other Kasm custom_startup.sh scripts.

PGREP="python3"
AGENT_LOG="$HOME/.coeadapt/logs/agent.log"

mkdir -p "$HOME/.coeadapt/logs"

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

kasm_exec() {
    /usr/bin/filter_ready
    /usr/bin/desktop_ready
}

kasm_startup() {
    if [ -n "$DISABLE_CUSTOM_STARTUP" ]; then
        echo "Coeadapt agent custom startup disabled"
        return
    fi

    # Respawn loop: keep agent services running
    while true; do
        if ! ss -tlnp 2>/dev/null | grep -q ":7700" || ! ss -tlnp 2>/dev/null | grep -q ":7701"; then
            /usr/bin/filter_ready
            /usr/bin/desktop_ready

            echo "[$(date)] Starting Coeadapt agent services..." >> "$AGENT_LOG"
            /usr/local/bin/coeadapt-agent >> "$AGENT_LOG" 2>&1
        fi
        sleep 5
    done
}

if [ -n "$GO" ] || [ -n "$ASSIGN" ]; then
    kasm_exec
else
    kasm_startup
fi
