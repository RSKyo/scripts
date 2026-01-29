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
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)/guard_source.source.sh"
guard_source

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)/log.source.sh"

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
  local platform base_dir root_dir bin_dir candidate

  platform="$(_resolve_platform)"
  if [ "$platform" = "unsupported" ]; then
    logw "infra" "Unsupported platform: $(uname -s)"
    return 1
  fi

  base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
  root_dir="$(cd "$base_dir/.." >/dev/null && pwd)"
  bin_dir="$root_dir/bin/$platform"

  # Special case: yt-dlp binary name on Linux
  if [ "$platform" = "linux" ] && [ "$name" = "yt-dlp" ]; then
    candidate="$bin_dir/yt-dlp_linux"
  elif [ "$platform" = "windows" ]; then
    candidate="$bin_dir/${name}.exe"
  else
    candidate="$bin_dir/${name}"
  fi

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
