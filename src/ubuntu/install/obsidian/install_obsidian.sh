#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly REPO="obsidianmd/obsidian-releases"
readonly APP_DIR="/opt/Obsidian"
readonly TARGET="${APP_DIR}/Obsidian.AppImage"
readonly SQ="${APP_DIR}/squashfs-root"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RELEASES_URL="${OBSIDIAN_RELEASES_URL:-https://api.github.com/repos/${REPO}/releases?per_page=30}"

log() { printf '%s [obsidian-install] %s\n' "$(date -u +%FT%TZ)" "$*" >&2; }
die() { local code=$1; shift; log "ERROR: $*"; exit "$code"; }

api_get() {
  local url=$1
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -fsSL -K <(printf 'header = "Authorization: Bearer %s"\n' "$GITHUB_TOKEN") \
      -H 'Accept: application/vnd.github+json' "$url"
  else
    curl -fsSL -H 'Accept: application/vnd.github+json' "$url"
  fi
}

case "$(uname -m)" in
  x86_64)  ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  *) die 5 "unsupported architecture: $(uname -m)" ;;
esac

apt-get update
apt-get install -y jq

tmp_json="$(mktemp)"
trap 'rm -f "$tmp_json"' EXIT

if [[ -n "${OBSIDIAN_RELEASES_FILE:-}" ]]; then
  cp "$OBSIDIAN_RELEASES_FILE" "$tmp_json"
  log "using offline releases file for testing"
elif ! api_get "$RELEASES_URL" > "$tmp_json"; then
  die 3 "failed to query GitHub releases API for ${REPO}"
fi

selected="$(jq -r --arg arch "$ARCH" -f "${SCRIPT_DIR}/select_asset.jq" "$tmp_json")"

if [[ -z "$selected" ]]; then
  die 2 "no ${ARCH} AppImage found in 30 most recent releases of ${REPO}. This is likely a temporary release (e.g., mobile-only). Check https://github.com/${REPO}/releases for the next desktop release."
fi

IFS=$'\t' read -r TAG DOWNLOAD_URL DIGEST <<< "$selected"
[[ "$DIGEST" == sha256:* ]] || die 6 "unexpected digest format: ${DIGEST}"
log "selected ${TAG}: ${DOWNLOAD_URL}"

if [[ "$ARCH" == "arm64" ]]; then
  apt-get install -y zlib1g-dev libfuse2
fi

install -d -m 755 "$APP_DIR"

if ! curl -fsSL "$DOWNLOAD_URL" -o "$TARGET"; then
  die 4 "failed to download ${TAG} from ${DOWNLOAD_URL}. Check network access and release availability."
fi

if ! echo "${DIGEST#sha256:}  ${TARGET}" | sha256sum -c --status -; then
  rm -f "$TARGET"
  die 6 "sha256 mismatch for ${TAG}. Downloaded file may be corrupted. Verify the release on GitHub."
fi
log "sha256 verified"

chmod 755 "$TARGET"

log "extracting AppImage"
(cd "$APP_DIR" && "$TARGET" --appimage-extract > /dev/null)
rm -f "$TARGET"
chown -R 1000:1000 "$APP_DIR"

[[ -f "${SQ}/AppRun" ]] || die 7 "unexpected AppImage layout after extraction: missing AppRun. The AppImage may be corrupted."

# Obsidian's desktop file name has changed over versions (e.g. obsidian.desktop
# vs md.obsidian.Obsidian.desktop). Find it dynamically instead of hardcoding.
DESKTOP_FILE="$(find "${SQ}" -maxdepth 1 -name '*.desktop' | head -n1)"
[[ -n "$DESKTOP_FILE" ]] || die 7 "unexpected AppImage layout after extraction: no .desktop file found. The AppImage may be corrupted."
log "found desktop file: $(basename "$DESKTOP_FILE")"

cat > "${SQ}/launcher" <<'EEOF'
#!/usr/bin/env bash
export APPDIR="${SQUASHFS_ROOT:-.}"
exec "${APPDIR}/AppRun" --no-sandbox "$@"
EEOF
sed -i "s@\${SQUASHFS_ROOT:-.}@${SQ}@" "${SQ}/launcher"
chmod 755 "${SQ}/launcher"

sed -i "s@^Exec=.*@Exec=${SQ}/launcher@" "${DESKTOP_FILE}"
sed -i "s@^Icon=.*@Icon=${SQ}/obsidian.png@" "${DESKTOP_FILE}"

install -d "$HOME/Desktop"
install -m 755 "${DESKTOP_FILE}" "$HOME/Desktop/obsidian.desktop"
install -m 755 "${DESKTOP_FILE}" /usr/share/applications/obsidian.desktop

log "installed ${TAG} to ${SQ}"
