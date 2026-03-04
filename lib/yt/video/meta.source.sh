#!/usr/bin/env bash
# Source-only library: yt.video.meta
# shellcheck disable=SC1091

# Prevent multiple sourcing
# [[ -n "${__YT_VIDEO_META_SOURCED+x}" ]] && return 0
# __YT_VIDEO_META_SOURCED=1

readonly YT_VIDEO_META_NAME='meta.json'

declare -Ar YT_VIDEO_META_FILTER_MAP=(
  [id]='.id // empty'
  [title]='.title // empty'
  [duration]='.duration // 0'
  [description]='.description // empty'
)

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/file.source.sh"
source "$LIB_DIR/yt/video/url.source.sh"

__yt_video_meta_derive() {
  local input="$1"
  local dir="$2"

  local id url file_name file_path

  id="$(yt_video_url_id "$input")" || {
    loge "Invalid input: $input"
    return 2
  }
  url="$(yt_video_url_canonical "$id")" || return 2
  printf -v file_name '%s.%s' "$id" "$YT_VIDEO_META_NAME"
  file_path="${dir%/}/${YT_CACHE_META_FOLDER}/${file_name}"

  printf '%s%s%s%s%s%s%s\n' \
    "$id" "$SEP" "$url" "$SEP" "$file_name" "$SEP" "$file_path"
}

__yt_video_meta_download() {
  local url="$1"
  local dir="$2"
  local file_name="$3"

  # shellcheck disable=SC2154
  "$yt_dlp" \
    --no-warnings \
    --skip-download \
    --dump-json \
    "$url" 2>/dev/null |
  file_write "$file_name" --dir "${dir%/}/${YT_CACHE_META_FOLDER}"
}

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
  IFS="$SEP" read -r id url file_name file_path < <(
    __yt_video_meta_derive "$input" "$dir") || return 2
  
  if (( refresh )) || [[ ! -s "$file_path" ]]; then
    __yt_video_meta_download \
    "$url" "$dir" "$file_name" || return 1
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
  IFS="$SEP" read -r id url file_name file_path < <(
    __yt_video_meta_derive "$input" "$dir") || return 2

  if (( refresh )) || [[ ! -s "$file_path" ]]; then
    __yt_video_meta_download \
    "$url" "$dir" "$file_name" || return 1
  fi

  # shellcheck disable=SC2154
  "$jq_bin" -r "$filter" "$file_path" || return 1
}
