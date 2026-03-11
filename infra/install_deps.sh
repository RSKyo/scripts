#!/usr/bin/env bash

set -e

logi() {
  printf '[INFO] %s\n' "$*"
}

loge() {
  printf '[ERROR] %s\n' "$*" >&2
}

require_command() {
  local cmd="${1:?missing command}"
  local pkg="${2:-$cmd}"

  command -v "$cmd" >/dev/null 2>&1 && {
    logi "$cmd already installed"
    return 0
  }

  logi "installing $pkg..."

  if command -v brew >/dev/null 2>&1; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew install "$pkg" || {
      loge "failed to install $pkg"
      return 1
    }
  else
    loge "Homebrew not found"
    return 1
  fi

  command -v "$cmd" >/dev/null 2>&1 || {
    loge "$cmd still not found after installing $pkg"
    return 1
  }

  logi "$cmd installed"
}

main() {
  # require_command yt-dlp
  # require_command ffmpeg
  # require_command ffprobe ffmpeg
  # require_command jq
  require_command cliclick
}

main "$@"