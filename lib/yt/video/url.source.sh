#!/usr/bin/env bash
# Source-only library: lib/yt/video/url

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_URL_SOURCED+x}" ]] && return 0
__YT_VIDEO_URL_SOURCED=1

# --- Constants ---------------------------------------------------------------

readonly YT_VIDEO_ID_REGEX='[A-Za-z0-9_-]{11}'
readonly YT_VIDEO_URL_YOUTU_BE_REGEX="youtu\.be/($YT_VIDEO_ID_REGEX)"
readonly YT_VIDEO_URL_WATCH_REGEX="[\?&]v=($YT_VIDEO_ID_REGEX)"
readonly YT_VIDEO_URL_EMBED_REGEX="/embed/($YT_VIDEO_ID_REGEX)"
readonly YT_VIDEO_URL_SHORTS_REGEX="/shorts/($YT_VIDEO_ID_REGEX)"
readonly YT_VIDEO_URL_PREFIX='https://www.youtube.com/watch?v='

# --- Public API --------------------------------------------------------------

yt_video_url_id() {
  local input="$1"
  [[ -z "$input" ]] && return 1

  local id

  # Plain video id
  if [[ "$input" =~ ^$YT_VIDEO_ID_REGEX$ ]]; then
    id="$input"

  # URL patterns
  elif [[ "$input" =~ $YT_VIDEO_URL_WATCH_REGEX ]]; then
    id="${BASH_REMATCH[1]}"

  elif [[ "$input" =~ $YT_VIDEO_URL_YOUTU_BE_REGEX ]]; then
    id="${BASH_REMATCH[1]}"

  elif [[ "$input" =~ $YT_VIDEO_URL_EMBED_REGEX ]]; then
    id="${BASH_REMATCH[1]}"

  elif [[ "$input" =~ $YT_VIDEO_URL_SHORTS_REGEX ]]; then
    id="${BASH_REMATCH[1]}"
  fi

  [[ -z "$id" ]] && return 1
  
  printf '%s\n' "$id"
}

yt_video_url_canonical() {
  local input="$1"
  [[ -z "$input" ]] && return 1

  local id
  id="$(yt_video_url_id "$input")"
  [[ -z "$id" ]] && return 1

  printf '%s%s\n' "$YT_VIDEO_URL_PREFIX" "$id"
}
