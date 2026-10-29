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

# Pass the token through a curl config on a file descriptor, not argv
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

# Scan recent releases instead of trusting "latest", which may be mobile-only.
# OBSIDIAN_RELEASES_FILE is for offline testing only; the build does not set it.
if [[ -n "${OBSIDIAN_RELEASES_FILE:-}" ]]; then
  cp "$OBSIDIAN_RELEASES_FILE" "$tmp_json"
elif ! api_get "$RELEASES_URL" > "$tmp_json"; then
  die 3 "failed to query GitHub releases API"
fi

selected="$(jq -r --arg arch "$ARCH" -f "${SCRIPT_DIR}/select_asset.jq" "$tmp_json")"

[[ -n "$selected" ]] || die 2 "no ${ARCH} AppImage with a digest in the 30 most recent releases of ${REPO}"

IFS=$'\t' read -r TAG DOWNLOAD_URL DIGEST <<< "$selected"
[[ "$DIGEST" == sha256:* ]] || die 6 "unexpected digest format: ${DIGEST}"
log "selected ${TAG}: ${DOWNLOAD_URL}"

if [[ "$ARCH" == "arm64" ]]; then
  apt-get install -y zlib1g-dev libfuse2
fi

install -d -m 755 "$APP_DIR"

if ! curl -fsSL "$DOWNLOAD_URL" -o "$TARGET"; then
  die 4 "download failed"
fi

if ! echo "${DIGEST#sha256:}  ${TARGET}" | sha256sum -c --status -; then
  rm -f "$TARGET"
  die 6 "sha256 mismatch for ${TAG}"
fi
log "sha256 verified"

chmod 755 "$TARGET"
(cd "$APP_DIR" && "$TARGET" --appimage-extract >/dev/null)
rm -f "$TARGET"
chown -R 1000:1000 "$APP_DIR"

[[ -f "${SQ}/AppRun" && -f "${SQ}/obsidian.desktop" ]] || die 7 "unexpected AppImage layout after extraction"

# \$@ is escaped so arguments are passed at launch time, not at build time
cat > "${SQ}/launcher" <<EOL
#!/usr/bin/env bash
export APPDIR=${SQ}
exec ${SQ}/AppRun --no-sandbox "\$@"
EOL
chmod 755 "${SQ}/launcher"

sed -i "s@^Exec=.*@Exec=${SQ}/launcher@" "${SQ}/obsidian.desktop"
sed -i "s@^Icon=.*@Icon=${SQ}/obsidian.png@" "${SQ}/obsidian.desktop"

install -d "$HOME/Desktop"
install -m 755 "${SQ}/obsidian.desktop" "$HOME/Desktop/obsidian.desktop"
install -m 755 "${SQ}/obsidian.desktop" /usr/share/applications/obsidian.desktop

log "installed ${TAG} to ${SQ}"