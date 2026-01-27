#!/usr/bin/env bash
# Source-only library: resolve_bin
# - purpose: resolve platform-specific binary paths
# - stdout: resolved absolute path
# - stderr: diagnostics only
# - return: 0 on success, non-zero on failure
#
# Location: scripts/core/resolve_bin.source.sh

# -------------------------------------------------
# Guard: must be sourced, not executed
# -------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "[ERROR] $(basename "${BASH_SOURCE[0]}") must be sourced, not executed." >&2
  exit 1
fi

# -------------------------------------------------
# Internal helpers
# -------------------------------------------------

_resolve_root() {
  # scripts/core -> scripts
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

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

  local base_dir platform bin_dir candidate

  base_dir="$(_resolve_root)"
  platform="$(_resolve_platform)"

  if [ "$platform" = "unsupported" ]; then
    echo "Unsupported platform: $(uname -s)" >&2
    return 1
  fi

  bin_dir="$base_dir/bin/$platform"

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
        echo "Binary found but not executable: $candidate" >&2
        echo "Hint: run 'chmod +x $candidate'" >&2
        return 1
    fi
    fi

    echo "Binary not found: $name (platform: $platform)" >&2
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
