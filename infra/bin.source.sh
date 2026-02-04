#!/usr/bin/env bash
# Source-only library: bin
#
# Purpose:
# - Provide pure functions to locate platform-specific external binaries
# - Bin paths are resolved relative to the repository root
#
# stdout: resolved absolute path
# stderr: none
# return: 0 on success, non-zero on failure

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__j9nOAFS3+x}" ]] && return 0
__j9nOAFS3=1

# -------------------------------------------------
# Platform detection
# -------------------------------------------------
_bin_platform() {
  case "$(uname -s)" in
    Darwin)  printf '%s\n' "darwin" ;;
    Linux)   printf '%s\n' "linux" ;;
    MINGW*|MSYS*|CYGWIN*) printf '%s\n' "windows" ;;
    *)       return 1 ;;
  esac
}

# -------------------------------------------------
# Core locator
# -------------------------------------------------
_bin_locate() {
  local name="$1"
  local platform real_name candidate

  platform="$(_bin_platform)" || return 1

  real_name="$name"
  case "$platform" in
    linux)
      [[ "$name" == "yt-dlp" ]] && real_name="yt-dlp_linux"
      ;;
    windows)
      real_name="${name}.exe"
      ;;
  esac

  candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../bin/$platform/$real_name"

  [[ -x "$candidate" ]] && printf '%s\n' "$candidate"
}

# -------------------------------------------------
# Public API
# -------------------------------------------------
bin_yt_dlp() {
  _bin_locate "yt-dlp"
}

bin_ffmpeg() {
  _bin_locate "ffmpeg"
}

bin_ffprobe() {
  _bin_locate "ffprobe"
}

bin_jq() {
  _bin_locate "jq"
}
