#!/usr/bin/env bash
# Source-only library: lib/yt/common

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
# [[ -n "${__YT_COMMON_SOURCED+x}" ]] && return 0
# __YT_COMMON_SOURCED=1


yt_video_set_id() {
  # --- ref vars ---
  local -n _id_ref="${1:?yt_video_set_id: missing id var}"
  shift
  # --- vars ---
  local _input="${1:?yt_video_set_id: missing video id or url}"

  if [[ "$_input" =~ ^$YT_VIDEO_ID_REGEX$ ]]; then
    _id_ref="$_input"
    return 0
  fi

  local _regex
  for _regex in \
    "$YT_VIDEO_URL_WATCH_REGEX" \
    "$YT_VIDEO_URL_YOUTU_BE_REGEX" \
    "$YT_VIDEO_URL_EMBED_REGEX" \
    "$YT_VIDEO_URL_SHORT_REGEX"
  do
    if [[ "$_input" =~ $_regex ]]; then
      _id_ref="${BASH_REMATCH[1]}"
      return 0
    fi
  done

  loge "invalid video id or url: $_input"
  return 1
}

yt_video_set_url() {
  # --- ref vars ---
  local -n _url_ref="${1:?yt_video_set_url: missing url var}"
  shift
  # --- vars ---
  local _input="${1:?yt_video_set_url: missing video id or url}"

  local _id
  yt_video_set_id _id "$_input" || return 1

  _url_ref="${YT_VIDEO_URL_PREFIX}${_id}"
}

yt_video_set_id_url() {
  # --- ref vars ---
  local -n _id_ref="${1:?yt_video_set_id_url: missing id var}"
  local -n _url_ref="${2:?yt_video_set_id_url: missing url var}"
  shift 2
  # --- vars ---
  local _input="${1:?yt_video_set_id_url: missing video id or url}"

  local _id
  yt_video_set_id _id "$_input" || return 1

  _id_ref="$_id"
  _url_ref="${YT_VIDEO_URL_PREFIX}${_id}"
}

yt_video_meta_set_name_path() {
  # --- ref vars ---
  local -n _name_ref="${1:?yt_video_meta_set_name_path: missing name var}"
  local -n _path_ref="${2:?yt_video_meta_set_name_path: missing path var}"
  shift 2
  # --- vars ---
  local _input="${1:?yt_video_meta_set_name_path: missing video id or url}"
  local _dir="${2:-"$YT_CACHE_DIR"}"

  local _id _name
  yt_video_set_id _id "$_input" || return 1

  _name="${_id}.${YT_CACHE_META_NAME}"

  _name_ref="$_name"
  _path_ref="${_dir%/}/${YT_CACHE_META_FOLDER}/${_name}"
}

yt_video_tracklist_set_name_path() {
  # --- ref vars ---
  local -n _name_ref="${1:?yt_video_tracklist_set_name_path: missing name var}"
  local -n _path_ref="${2:?yt_video_tracklist_set_name_path: missing path var}"
  shift 2
  # --- vars ---
  local _input="${1:?yt_video_tracklist_set_name_path: missing video id or url}"
  local _dir="${2:-"$YT_CACHE_DIR"}"

  local _id _name
  yt_video_set_id _id "$_input" || return 1

  _name="${_id}.${YT_CACHE_TRACKLIST_NAME}"

  _name_ref="$_name"
  _path_ref="${_dir%/}/${YT_CACHE_TRACKLIST_FOLDER}/${_name}"
}
