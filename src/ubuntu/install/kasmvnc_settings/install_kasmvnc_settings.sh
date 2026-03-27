#!/usr/bin/env bash
set -ex

# ============================================================================
# KasmVNC High-Quality Settings
# Patches the existing kasmvnc.yaml to set 60 FPS and max quality
# without replacing the entire file (preserves base image defaults)
# ============================================================================

KASMVNC_YAML="/etc/kasmvnc/kasmvnc.yaml"

if [ ! -f "${KASMVNC_YAML}" ]; then
  echo "WARNING: ${KASMVNC_YAML} not found, skipping VNC config"
  exit 0
fi

# Patch encoding settings for maximum quality
# Use sed to modify specific values in the existing config

# Frame rate: 24 -> 60
sed -i 's/max_frame_rate: [0-9]*/max_frame_rate: 60/' "${KASMVNC_YAML}"

# Rect encoding quality: raise min/max
sed -i '/rect_encoding_mode:/,/video_encoding_mode:/ {
  s/min_quality: [0-9]*/min_quality: 8/
  s/max_quality: [0-9]*/max_quality: 9/
  s/consider_lossless_quality: [0-9]*/consider_lossless_quality: 9/
}' "${KASMVNC_YAML}"

# Video encoding quality: raise JPEG and WebP
sed -i '/video_encoding_mode:/,/compare_framebuffer:/ {
  s/jpeg_quality: -\?[0-9]*/jpeg_quality: 8/
  s/webp_quality: -\?[0-9]*/webp_quality: 8/
}' "${KASMVNC_YAML}"

# Resolution: set default to 1920x1080
sed -i '/desktop:/,/network:/ {
  s/width: [0-9]*/width: 1920/
  s/height: [0-9]*/height: 1080/
}' "${KASMVNC_YAML}"

echo "KasmVNC patched: 1920x1080 @ 60fps, quality 8-9/9"
