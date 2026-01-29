#!/usr/bin/env bash
# Source-only library: yt_fetch_description <url>
# - stdout: description if found
# - stderr: diagnostics only
# - return: always 0 (check stdout)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "[ERROR] $(basename "${BASH_SOURCE[0]}") must be sourced, not executed." >&2
  exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/yt.url_id.source.sh"

yt_fetch_description() {
  local url="$1"
  local id="" watch_url="" desc=""

  [[ -n "$url" ]] || return 0

  id="$(yt_url_id "$url")"
  if [[ -z "$id" ]]; then
    echo "[WARN] invalid url: $url" >&2
    return 0
  fi

  watch_url="https://www.youtube.com/watch?v=${id}"

  desc="$(
    yt-dlp \
      --no-warnings \
      --skip-download \
      --print description \
      "$watch_url" 
  )"

  [[ -n "$desc" ]] && printf '%s\n' "$desc"
  return 0
}
