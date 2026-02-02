#!/usr/bin/env bash
# Source-only library: resolve_bin
# - purpose: resolve platform-specific binary paths
# - stdout: resolved absolute path
# - stderr: diagnostics only
# - return: 0 on success, non-zero on failure
#
# Location: scripts/infra/resolve_bin.source.sh

# Prevent multiple sourcing
[[ -n "${__XISf8HUw+x}" ]] && return 0
__XISf8HUw=1

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)/bootstrap.source.sh"

_resolve_platform() {
  case "$(uname -s)" in
    Darwin)
      echo "darwin"
      ;;
    Linux)
      echo "linux"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "windows"
      ;;
    *)
      echo "unsupported"
      ;;
  esac
}

_resolve_exec() {
  local name="$1"
  local platform
  local real_name candidate

  platform="$(_resolve_platform)"
  if [ "$platform" = "unsupported" ]; then
    logw "infra" "Unsupported platform: $(uname -s)"
    return 1
  fi
  
  real_name="$name"
  case "$platform" in
    linux)
      [[ "$name" == "yt-dlp" ]] && real_name="yt-dlp_linux"
      ;;
    windows)
      real_name="${name}.exe"
      ;;
  esac

  candidate="$BIN_DIR/$platform/$real_name"


  if [ -e "$candidate" ]; then
    if [ -x "$candidate" ]; then
        echo "$candidate"
        return 0
    else
        loge "infra" "Binary found but not executable: $candidate"
        loge "infra" "Hint: run 'chmod +x $candidate'"
        return 1
    fi
  fi

  loge "infra" "Binary not found: $name (platform: $platform)"
  loge "infra" "Expected at: $candidate"
  return 1
}

# -------------------------------------------------
# Public resolvers
# -------------------------------------------------

resolve_yt_dlp() {
  _resolve_exec "yt-dlp"
}

resolve_ffmpeg() {
  _resolve_exec "ffmpeg"
}

resolve_ffprobe() {
  _resolve_exec "ffprobe"
}

resolve_jq() {
  _resolve_exec "jq"
}
