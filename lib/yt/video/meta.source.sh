#!/usr/bin/env bash
# Source-only library: lib/yt/video/meta
# shellcheck disable=SC1091,SC2154

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_META_SOURCED+x}" ]] && return 0
__YT_VIDEO_META_SOURCED=1

# --- Dependencies ------------------------------------------------------------
# Dependencies (bootstrap must be sourced by the entry script)

source "$LIB_DIR/text.source.sh"
source "$LIB_DIR/yt/const.source.sh"
source "$LIB_DIR/yt/common.source.sh"

# --- Public API --------------------------------------------------------------

__yt_video_meta_cache_build() {
  local url="$1"
  local file="$2"

  "$yt_dlp" \
    --no-warnings \
    --skip-download \
    --dump-json \
    "$url" 2>/dev/null |
  text_file "$file" || return 1
}

yt_video_meta_download() {
  local input="${1:?yt_video_meta_download: missing video id or url}"
  local dir="${2:-"$YT_CACHE_DIR"}"
  
  local meta_path
  meta_path="$(yt_video_meta_path "$input" "$dir")"  || return 1
  
  if [[ ! -s "$meta_path" ]]; then
    local url
    url="$(yt_video_url "$input")" || return 2

    logi "meta fetch: $meta_path"
    __yt_video_meta_cache_build "$url" "$meta_path" || {
      loge "meta fetch failed: $meta_path"
      return 1
    }

  else
    logi "meta cache: $meta_path"
  fi
  
  return 0
}

yt_video_meta() {
  local input="${1:?yt_video_meta: missing video id or url}"
  local field="${2:?yt_video_meta: missing meta field}"
  local dir="${3:-"$YT_CACHE_DIR"}"

  local filter
  filter="${YT_VIDEO_META_FILTER_MAP[$field]}"
  [[ -n "$filter" ]] || return 2

  yt_video_meta_download "$input" "$dir" || return 1

  local meta_path
  meta_path="$(yt_video_meta_path "$input" "$dir")"  || return 1
  
  # shellcheck disable=SC2154
  "$jq_bin" -r "$filter" "$meta_path" || return 1
}
