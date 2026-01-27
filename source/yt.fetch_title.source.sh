#!/usr/bin/env bash
# Source-only library: yt_fetch_title <url>
# - stdout: title if found
# - stderr: diagnostics only
# - return: always 0 (check stdout)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "[ERROR] $(basename "${BASH_SOURCE[0]}") must be sourced, not executed." >&2
  exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/yt.url_id.source.sh"

yt_fetch_title() {
  local url="$1"
  local id="" watch_url="" title=""

  [[ -n "$url" ]] || return 0

  id="$(yt_url_id "$url")"
  if [[ -z "$id" ]]; then
    echo "[WARN] invalid url: $url" >&2
    return 0
  fi

  watch_url="https://www.youtube.com/watch?v=${id}"

  # 1) oEmbed (fast, sometimes blocked)
  title="$(
    curl -L \
      -H "User-Agent: Mozilla/5.0" \
      --connect-timeout 5 \
      --max-time 8 \
      "https://www.youtube.com/oembed?format=json&url=${watch_url}" \
    | jq -r '.title // empty' \
    | head -n 1
  )"

  # 2) HTML <title> (higher hit rate)
  if [[ -z "$title" ]]; then
    title="$(
      curl -L \
        -H "User-Agent: Mozilla/5.0" \
        --connect-timeout 5 \
        --max-time 8 \
        "$watch_url" \
      | sed -n 's:.*<title>\(.*\)</title>.*:\1:p' \
      | sed 's/ - YouTube$//' \
      | head -n 1
    )"
  fi

  # 3) yt-dlp (most reliable, slower)
  if [[ -z "$title" ]]; then
    title="$(
      yt-dlp \
        --no-warnings \
        --skip-download \
        --print title \
        "$watch_url" \
      | head -n 1
    )"
  fi

  [[ -n "$title" ]] && printf '%s\n' "$title"
  return 0
}
