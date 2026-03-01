#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034
# bootstrap (source-only)
# Initialize project paths, platform, and required binaries.

set -o pipefail

# Prevent multiple sourcing
[[ -n "${__BOOTSTRAP_SOURCED+x}" ]] && return 0
__BOOTSTRAP_SOURCED=1

# Directories
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)" || exit 1
INFRA_DIR="$ROOT_DIR/infra"
LIB_DIR="$ROOT_DIR/lib"
ACTION_DIR="$ROOT_DIR/action"
BIN_DIR="$ROOT_DIR/bin"

readonly ROOT_DIR INFRA_DIR LIB_DIR ACTION_DIR BIN_DIR

# Logging
source "$INFRA_DIR/log.source.sh"

# Platform
if [[ -z "${PLATFORM:-}" ]]; then
  case "$(uname -s)" in
    Darwin)  PLATFORM="darwin" ;;
    Linux)   PLATFORM="linux" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
    *)
      loge "BOOTSTRAP" "Unsupported platform: $(uname -s)"
      exit 1
      ;;
  esac
fi

readonly PLATFORM

# Binaries
BIN_PLATFORM_DIR="$BIN_DIR/$PLATFORM"
readonly BIN_PLATFORM_DIR

case "$PLATFORM" in
  darwin)
    yt_dlp="$BIN_PLATFORM_DIR/yt-dlp"
    ffmpeg="$BIN_PLATFORM_DIR/ffmpeg"
    ffprobe="$BIN_PLATFORM_DIR/ffprobe"
    jq_bin="$BIN_PLATFORM_DIR/jq-macos-amd64"
    ;;
  linux)
    yt_dlp="$BIN_PLATFORM_DIR/yt-dlp_linux"
    ffmpeg="$BIN_PLATFORM_DIR/ffmpeg"
    ffprobe="$BIN_PLATFORM_DIR/ffprobe"
    jq_bin="$BIN_PLATFORM_DIR/jq-linux-amd64"
    ;;
  windows)
    yt_dlp="$BIN_PLATFORM_DIR/yt-dlp.exe"
    ffmpeg="$BIN_PLATFORM_DIR/ffmpeg.exe"
    ffprobe="$BIN_PLATFORM_DIR/ffprobe.exe"
    jq_bin="$BIN_PLATFORM_DIR/jq-win64.exe"
    ;;
  *)
    loge "[bootstrap] unsupported platform: $PLATFORM"
    exit 1
    ;;
esac

for bin in yt_dlp ffmpeg ffprobe jq_bin; do
  path="${!bin}"
  if [[ ! -x "$path" ]]; then
    loge "BOOTSTRAP" "Executable not found or not runnable: $path"
    exit 1
  fi
done

readonly yt_dlp ffmpeg ffprobe jq_bin

# Wrappers
__require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    loge "BOOTSTRAP" "Required command not found: $cmd"
    return 127
  fi
}

__perl() {
  __require_cmd perl || return 127
  command perl -CS -Mutf8 -e "$1" "${@:2}"
}

__awk() {
  __require_cmd awk || return 127
  command awk "$@"
}
