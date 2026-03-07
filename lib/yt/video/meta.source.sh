#!/usr/bin/env bash
# Source-only library: lib/yt/video/meta
# shellcheck disable=SC1091

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_META_SOURCED+x}" ]] && return 0
__YT_VIDEO_META_SOURCED=1

# --- Dependencies ------------------------------------------------------------

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/file.source.sh"

source "$LIB_DIR/yt/video/url.source.sh"

# --- Constants ---------------------------------------------------------------

declare -Ar YT_VIDEO_META_FILTER_MAP=(
  [id]='.id // empty'
  [title]='.title // empty'
  [duration]='.duration // 0'
  [description]='.description // empty'
)

# --- Internal Helpers --------------------------------------------------------

__yt_video_meta_cache_build() {
  local url="$1"
  local file_path="$2"

  logi "fetch video meta: $url"

  # shellcheck disable=SC2154
  "$yt_dlp" \
    --no-warnings \
    --skip-download \
    --dump-json \
    "$url" 2>/dev/null |
  file_write "$file_path" || {
    loge "failed to download video meta: $url"
    return 1
  }

  logi "meta cache saved: $file_path"
}

# --- Public API --------------------------------------------------------------

yt_video_meta_download() {
  local input="${1:?yt_video_meta_download: missing url}"
  shift
  local dir="$YT_CACHE_DIR"
  local refresh=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) shift; [[ $# -ge 1 ]] || return 2; dir="$1"; shift ;;
      --refresh) shift; refresh=1 ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  local id url file_name file_path
  id="$(yt_video_url_id "$input")" || {
    loge "Invalid input: $input"
    return 2
  }
  url="$(yt_video_url_canonical "$id")" || return 2
  file_name="${id}.${YT_CACHE_META_NAME}"
  file_path="${dir%/}/${YT_CACHE_META_FOLDER}/${file_name}"
  
  if (( refresh )) || [[ ! -s "$file_path" ]]; then
    __yt_video_meta_cache_build "$url" "$file_path" || return 1
  else
    logi "meta cache already exists: $file_path"
  fi
  
  return 0
}

yt_video_meta() {
  local input="${1:?yt_video_meta: missing url}"
  local field="${2:?yt_video_meta: missing meta field}"
  shift 2
  local dir="$YT_CACHE_DIR"
  local refresh=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) shift; [[ $# -ge 1 ]] || return 2; dir="$1"; shift ;;
      --refresh) shift; refresh=1 ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  local filter
  filter="${YT_VIDEO_META_FILTER_MAP[$field]}"
  [[ -n "$filter" ]] || return 2

  local id url file_name file_path
  id="$(yt_video_url_id "$input")" || {
    loge "Invalid input: $input"
    return 2
  }
  url="$(yt_video_url_canonical "$id")" || return 2
  file_name="${id}.${YT_CACHE_META_NAME}"
  file_path="${dir%/}/${YT_CACHE_META_FOLDER}/${file_name}"

  if (( refresh )) || [[ ! -s "$file_path" ]]; then
    __yt_video_meta_cache_build "$url" "$file_path" || return 1
  fi

  # shellcheck disable=SC2154
  "$jq_bin" -r "$filter" "$file_path" || return 1
}
