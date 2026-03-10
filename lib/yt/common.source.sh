#!/usr/bin/env bash
# Source-only library: lib/yt/common

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_COMMON_SOURCED+x}" ]] && return 0
__YT_COMMON_SOURCED=1

# --- Public API --------------------------------------------------------------

yt_video_id() {
  local input="$1"

  if [[ "$input" =~ ^$YT_VIDEO_ID_REGEX$ ]]; then
    printf '%s\n' "$input"
    return 0
  fi

  local regex
  for regex in \
    "$YT_VIDEO_URL_WATCH_REGEX" \
    "$YT_VIDEO_URL_YOUTU_BE_REGEX" \
    "$YT_VIDEO_URL_EMBED_REGEX" \
    "$YT_VIDEO_URL_SHORT_REGEX"
  do
    if [[ "$input" =~ $regex ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done

  loge "invalid video id or url: $input"
  return 1
}

yt_video_url() {
  local input="$1"
  local id
  id="$(yt_video_id "$input")" || return 2
  printf '%s\n' "${YT_VIDEO_URL_PREFIX}${id}"
}

yt_video_meta_name() {
  local input="$1"
  local id
  id="$(yt_video_id "$input")" || return 2
  printf '%s\n' "${id}.${YT_CACHE_META_NAME}"
}

yt_video_meta_path() {
  local input="$1"
  local dir="${2:-"$YT_CACHE_DIR"}"
  local name
  name="$(yt_video_meta_name "$input")" || return 2
  printf '%s\n' "${dir%/}/${YT_CACHE_META_FOLDER}/${name}"
}

yt_video_tracklist_name() {
  local input="$1"
  local id
  id="$(yt_video_id "$input")" || return 2
  printf '%s\n' "${id}.${YT_CACHE_TRACKLIST_NAME}"
}

yt_video_tracklist_path() {
  local input="$1"
  local dir="${2:-"$YT_CACHE_DIR"}"
  local name
  name="$(yt_video_tracklist_name "$input")" || return 2
  printf '%s\n' "${dir%/}/${YT_CACHE_TRACKLIST_FOLDER}/${name}"
}
