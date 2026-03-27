#!/usr/bin/env bash

START_COMMAND="/usr/local/bin/openclaw"
PGREP="node"
GATEWAY_LOG="$HOME/.openclaw/gateway.log"

ARGS=${APP_ARGS:-"gateway"}

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

    # Open the gateway UI in the default browser
    set +e
    xdg-open "http://localhost:18789" &
    set -e
}

kasm_startup() {
    if [ -n "$DISABLE_CUSTOM_STARTUP" ]; then
        echo "CareerClaw custom startup disabled"
        return
    fi

    # Respawn loop: keep the gateway running
    while true; do
        # Check if gateway is already running on port 18789
        if ! ss -tlnp 2>/dev/null | grep -q ":18789"; then
            /usr/bin/filter_ready
            /usr/bin/desktop_ready

            echo "Starting CareerClaw gateway..."
            set +e
            $START_COMMAND $ARGS >> "$GATEWAY_LOG" 2>&1 &
            set -e

            # Wait for the gateway to be ready
            for i in $(seq 1 30); do
                if ss -tlnp 2>/dev/null | grep -q ":18789"; then
                    echo "CareerClaw gateway is ready on port 18789"
                    break
                fi
                sleep 1
            done
        fi
        sleep 5
    done
}

if [ -n "$GO" ] || [ -n "$ASSIGN" ]; then
    kasm_exec
else
    kasm_startup
fi
