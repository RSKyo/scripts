#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.video.id
#
# Semantics:
# - Parse YouTube video input forms and extract videoId
# - Supported forms:
#   - https://www.youtube.com/watch?v=<id>
#   - https://youtu.be/<id>
#   - https://www.youtube.com/embed/<id>
#   - https://www.youtube.com/shorts/<id>
#
# stdout: videoId
# stderr: none
# return: always 0 (check stdout)

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__YT_VIDEO_ID_SOURCED+x}" ]] && return 0
__YT_VIDEO_ID_SOURCED=1

# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_video_id() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  local id=""
  local re_id='[A-Za-z0-9_-]{11}'

  if [[ "$input" =~ ^$re_id$ ]]; then
    printf '%s\n' "$input"
    return 0
  fi

  local re_youtu_be='youtu\.be/('"$re_id"')'
  local re_watch='[?&]v=('"$re_id"')'
  local re_embed='/embed/('"$re_id"')'
  local re_shorts='/shorts/('"$re_id"')'

  if [[ "$input" =~ $re_youtu_be ]]; then
    id="${BASH_REMATCH[1]}"
  elif [[ "$input" =~ $re_watch ]]; then
    id="${BASH_REMATCH[1]}"
  elif [[ "$input" =~ $re_embed ]]; then
    id="${BASH_REMATCH[1]}"
  elif [[ "$input" =~ $re_shorts ]]; then
    id="${BASH_REMATCH[1]}"
  fi

  [[ -n "$id" ]] && printf '%s\n' "$id"
  return 0
}
