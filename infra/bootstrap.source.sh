#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: bootstrap
#
# Role:
# - Initialize runtime context for this repository
# - Define project root and directory layout
# - Detect or accept target platform
# - Bind and export required repo-local external tools
#
# Contract:
# - Must be sourced (not executed)
# - PLATFORM may be preset by caller; otherwise detected at runtime
# - On success, common paths and tool variables are available
# - On failure, exits with non-zero status

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__BOOTSTRAP_SOURCED+x}" ]] && return 0
__BOOTSTRAP_SOURCED=1

# -------------------------------------------------
# Resolve project directories
# -------------------------------------------------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
INFRA_DIR="$ROOT_DIR/infra"
LIB_DIR="$ROOT_DIR/lib"
ACTION_DIR="$ROOT_DIR/action"
BIN_DIR="$ROOT_DIR/bin"

export ROOT_DIR INFRA_DIR LIB_DIR ACTION_DIR BIN_DIR

# -------------------------------------------------
# Logging
# -------------------------------------------------
source "$INFRA_DIR/log.source.sh"

# -------------------------------------------------
# Platform detection (allow preset)
# -------------------------------------------------
if [[ -z "${PLATFORM:-}" ]]; then
  case "$(uname -s)" in
    Darwin)  PLATFORM="darwin" ;;
    Linux)   PLATFORM="linux" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
    *) echo "Unsupported platform" >&2; exit 1 ;;
  esac
fi

export PLATFORM

# -------------------------------------------------
# Resolve binaries (exact filenames)
# -------------------------------------------------
case "$PLATFORM" in
  darwin)
    yt_dlp="$BIN_DIR/$PLATFORM/yt-dlp"
    ffmpeg="$BIN_DIR/$PLATFORM/ffmpeg"
    ffprobe="$BIN_DIR/$PLATFORM/ffprobe"
    jq="$BIN_DIR/$PLATFORM/jq-macos-amd64"
    ;;
  linux)
    yt_dlp="$BIN_DIR/$PLATFORM/yt-dlp_linux"
    ffmpeg="$BIN_DIR/$PLATFORM/ffmpeg"
    ffprobe="$BIN_DIR/$PLATFORM/ffprobe"
    jq="$BIN_DIR/$PLATFORM/jq-linux-amd64"
    ;;
  windows)
    yt_dlp="$BIN_DIR/$PLATFORM/yt-dlp.exe"
    ffmpeg="$BIN_DIR/$PLATFORM/ffmpeg.exe"
    ffprobe="$BIN_DIR/$PLATFORM/ffprobe.exe"
    jq="$BIN_DIR/$PLATFORM/jq-win64.exe"
    ;;
esac

export yt_dlp ffmpeg ffprobe jq
