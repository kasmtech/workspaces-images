#!/bin/bash
set -euo pipefail

DEFINITION_FILE="$(pwd)/ci-scripts/template-vars.yaml"
CI_FILE="$(pwd)/.gitlab-ci.yml"
export TARGET_TAG="local_build"
export TARGET_IMAGE=""
export BASE_SUFFIX=""
BASE_TAG_OVERRIDE=""
MODE=""

YQ_VERSION="v4.53.3"
YQ_BIN="${HOME}/.cache/kasm/yq/${YQ_VERSION}/yq"

declare -A YQ_SHA256=(
    ["linux_amd64"]="fa52a4e758c63d38299163fbdd1edfb4c4963247918bf9c1c5d31d84789eded4"
    ["linux_arm64"]="578648e463a11c1b6db6010cbf41eafed6bee79466fcffa1bb446672cf7945ea"
    ["darwin_amd64"]="b4ba1ecce3c47f00803f4f964de38394326c7a32eb6540616e04fb2935a0f08d"
    ["darwin_arm64"]="877de31753a4dd2401aa048937aa9a7fc4d5f6ce858cf31508c5802954297213"
)

ensure_yq() {
    [[ -x "$YQ_BIN" ]] && return
    local os arch platform
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    [[ "$arch" == "x86_64" ]] && arch="amd64"
    [[ "$arch" =~ ^(aarch64|arm64)$ ]] && arch="arm64"
    platform="${os}_${arch}"
    local expected="${YQ_SHA256[$platform]:-}"
    [[ -z "$expected" ]] && { echo "Error: unsupported platform: $platform" >&2; exit 1; }
    echo "Downloading yq ${YQ_VERSION} for ${platform}..." >&2
    mkdir -p "$(dirname "$YQ_BIN")"
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_${platform}" \
        -o "${YQ_BIN}.tmp"
    local actual
    actual=$(sha256sum "${YQ_BIN}.tmp" | awk '{print $1}')
    if [[ "$actual" != "$expected" ]]; then
        rm -f "${YQ_BIN}.tmp"
        echo "Error: sha256 mismatch for yq ${YQ_VERSION} (${platform})" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        exit 1
    fi
    mv "${YQ_BIN}.tmp" "$YQ_BIN"
    chmod +x "$YQ_BIN"
}

ensure_yq
YQ="$YQ_BIN"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --list-images                       List all available image names
  --list-images-build-commands        List docker build commands for all images
  --list-image-build-command <name>   Print the docker build command for a specific image
  --build <name>                      Build a specific image
  -t, --target-tag <tag>              Tag for the built image (default: local_build)
  --private                           Use private base images (appends -private to BASE_IMAGE)
  --base-tag <tag>                    Override the base image tag (default: from .gitlab-ci.yml)
  --help                              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --list-images)                MODE="list-images"; shift ;;
        --list-images-build-commands) MODE="list-commands"; shift ;;
        --list-image-build-command)   MODE="list-command"; TARGET_IMAGE="$2"; shift 2 ;;
        --build)                      MODE="build"; TARGET_IMAGE="$2"; shift 2 ;;
        -t|--target-tag)              TARGET_TAG="$2"; shift 2 ;;
        --private)                    BASE_SUFFIX="-private"; shift ;;
        --base-tag)                   BASE_TAG_OVERRIDE="$2"; shift 2 ;;
        --help)                       usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

[[ -z "$MODE" ]] && { echo "No command specified." >&2; usage >&2; exit 1; }

export BASE_TAG
BASE_TAG=$("$YQ" '.variables.BASE_TAG' "$CI_FILE")
[[ -n "$BASE_TAG_OVERRIDE" ]] && BASE_TAG="$BASE_TAG_OVERRIDE"

export DOCKER_PREFIX=""
docker info &>/dev/null 2>&1 || DOCKER_PREFIX="sudo "

case "$MODE" in
    list-images)
        "$YQ" '(.multiImages[], .singleImages[]) | "kasmweb/" + .name' "$DEFINITION_FILE"
        ;;
    list-commands)
        "$YQ" '(.multiImages[], .singleImages[]) |
          strenv(DOCKER_PREFIX) + "docker build -t kasmweb/" + .name + ":" + strenv(TARGET_TAG) +
          " --build-arg BASE_IMAGE=" + .base + strenv(BASE_SUFFIX) +
          " --build-arg BASE_TAG=" + strenv(BASE_TAG) +
          " -f " + .dockerfile +
          " ."' \
          "$DEFINITION_FILE"
        ;;
    list-command|build)
        cmd=$("$YQ" '(.multiImages[], .singleImages[]) |
          select(("kasmweb/" + .name) == strenv(TARGET_IMAGE)) |
          strenv(DOCKER_PREFIX) + "docker build -t kasmweb/" + .name + ":" + strenv(TARGET_TAG) +
          " --build-arg BASE_IMAGE=" + .base + strenv(BASE_SUFFIX) +
          " --build-arg BASE_TAG=" + strenv(BASE_TAG) +
          " -f " + .dockerfile +
          " ."' \
          "$DEFINITION_FILE")
        [[ -z "$cmd" ]] && { echo "Image not found: $TARGET_IMAGE" >&2; exit 1; }
        [[ "$MODE" == "list-command" ]] && echo "$cmd" || eval "$cmd"
        ;;
esac
