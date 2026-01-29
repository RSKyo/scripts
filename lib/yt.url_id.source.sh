#!/usr/bin/env bash
# Source-only library: yt_url_id <url>
# - stdout: videoId if found
# - stderr: diagnostics only
# - return: always 0 (check stdout)

# Prevent multiple sourcing
[[ -n "${__sB6IJl88+x}" ]] && return 0
__sB6IJl88=1

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "[ERROR] $(basename "${BASH_SOURCE[0]}") must be sourced, not executed." >&2
  exit 1
fi

yt_url_id() {
  local url="$1"
  local re='[A-Za-z0-9_-]{11}'

  [[ -n "$url" ]] || return 0

  # youtu.be / embed / shorts：路径型 ID
  if [[ "$url" =~ youtu\.be/($re) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"; return 0
  fi
  if [[ "$url" =~ /embed/($re) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"; return 0
  fi
  if [[ "$url" =~ /shorts/($re) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"; return 0
  fi

  # watch?v=：查询参数型 ID
  if [[ "$url" == *"youtube.com/watch"* && "$url" == *\?* ]]; then
    local query="" param="" id=""
    query="${url#*\?}"
    query="${query%%#*}"

    local params=()
    IFS='&' read -r -a params <<< "$query"

    for param in "${params[@]}"; do
      [[ "$param" == v=* ]] || continue
      id="${param#v=}"
      [[ "$id" =~ ^$re$ ]] || return 0
      printf '%s\n' "$id"
      return 0
    done
  fi

  # Not matched
  return 0
}