#!/bin/bash
set -ex

# Fix for "Grey Screen" issue: manually create xstartup to force XFCE launch
VNC_DIR="/home/kasm-user/.vnc"
mkdir -p "$VNC_DIR"

cat > "$VNC_DIR/xstartup" <<'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF

chmod +x "$VNC_DIR/xstartup"
chown 1000:0 "$VNC_DIR/xstartup"
