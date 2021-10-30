#!/usr/bin/env bash
/usr/bin/desktop_ready
echo "Starting Firefox"
onboard & 
unclutter -idle 0 -root -jitter 10000 & 
mousetweaks --ssc --ssc-time=0.5 --daemonize & 
pid_xfce4_session=$(pgrep xfce4-session) 
DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/${pid_xfce4_session}/environ|cut -d= -f2-) 
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS} 
export XDG_CURRENT_DESKTOP=XFCE

FORCE=$2 
URL=${1:-$LAUNCH_URL}  
if [ -n "$URL" ] && ( [ -z "$DISABLE_CUSTOM_STARTUP" ] ||  [ -n "$FORCE" ] ) ; then 
    if [ -f /tmp/custom_startup.lck ] ; then  
        echo "custom_startup already running!" 
        exit 1 
    fi 
    while true 
    do 
        if ! pgrep -x firefox > /dev/null 
        then
            firefox -width ${VNC_RESOLUTION/x*/} -height ${VNC_RESOLUTION/*x/} $URL 
            sleep 10 && wmctrl -r :ACTIVE: -b toggle,maximized_vert,maximized_horz &  
        fi
        sleep 1
    done 
fi