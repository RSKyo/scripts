#!/usr/bin/env bash
# Source-only library: bootstrap
#
# Role:
# - Initialize runtime context for this repository
# - Define project root and directory layout
# - Resolve and export required external tool handles
#
# Contract:
# - Must be sourced (not executed)
# - On success, common paths and tool variables are available
# - On failure, exits with non-zero status

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__qKHYLlwK+x}" ]] && return 0
__qKHYLlwK=1

# -------------------------------------------------
# Resolve project directories
# -------------------------------------------------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
INFRA_DIR="$ROOT_DIR/infra"
LIB_DIR="$ROOT_DIR/lib"
ACTION_DIR="$ROOT_DIR/action"
BIN_DIR="$ROOT_DIR/bin"

export ROOT_DIR INFRA_DIR LIB_DIR ACTION_DIR BIN_DIR

# shellcheck source=/dev/null
source "$INFRA_DIR/log.source.sh"

# -------------------------------------------------
# Resolve common tools
# -------------------------------------------------
# shellcheck source=/dev/null
source "$INFRA_DIR/bin.source.sh"

# Resolve project common tools
yt_dlp="$(bin_yt_dlp)"     || { echo "yt-dlp not found" >&2; exit 1; }
ffmpeg="$(bin_ffmpeg)"     || { echo "ffmpeg not found" >&2; exit 1; }
ffprobe="$(bin_ffprobe)"   || { echo "ffprobe not found" >&2; exit 1; }
jq="$(bin_jq)"             || { echo "jq not found" >&2; exit 1; }

export yt_dlp ffmpeg ffprobe jq
