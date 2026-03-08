#!/usr/bin/env bash
# Source-only library: lib/yt/video/url

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_URL_SOURCED+x}" ]] && return 0
__YT_VIDEO_URL_SOURCED=1

# --- Constants ---------------------------------------------------------------

readonly __YT_VIDEO_ID_REGEX='[A-Za-z0-9_-]{11}'
readonly __YT_VIDEO_URL_YOUTU_BE_REGEX="youtu\.be/($__YT_VIDEO_ID_REGEX)"
readonly __YT_VIDEO_URL_WATCH_REGEX="[\?&]v=($__YT_VIDEO_ID_REGEX)"
readonly __YT_VIDEO_URL_EMBED_REGEX="/embed/($__YT_VIDEO_ID_REGEX)"
readonly __YT_VIDEO_URL_SHORTS_REGEX="/shorts/($__YT_VIDEO_ID_REGEX)"
readonly __YT_VIDEO_URL_PREFIX='https://www.youtube.com/watch?v='

# --- Public API --------------------------------------------------------------

yt_video_url_id() {
  local input="$1"
  [[ -z "$input" ]] && return 1

  local id

  # Plain video id
  if [[ "$input" =~ ^$__YT_VIDEO_ID_REGEX$ ]]; then
    id="$input"

  # URL patterns
  elif [[ "$input" =~ $__YT_VIDEO_URL_WATCH_REGEX ]]; then
    id="${BASH_REMATCH[1]}"

  elif [[ "$input" =~ $__YT_VIDEO_URL_YOUTU_BE_REGEX ]]; then
    id="${BASH_REMATCH[1]}"

  elif [[ "$input" =~ $__YT_VIDEO_URL_EMBED_REGEX ]]; then
    id="${BASH_REMATCH[1]}"

  elif [[ "$input" =~ $__YT_VIDEO_URL_SHORTS_REGEX ]]; then
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

  printf '%s%s\n' "$__YT_VIDEO_URL_PREFIX" "$id"
}


