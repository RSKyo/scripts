#!/usr/bin/env bash
# Source-only library: yt.video.meta
# shellcheck disable=SC1091

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_META_SOURCED+x}" ]] && return 0
__YT_VIDEO_META_SOURCED=1

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
  local sub_dir="$3"

  local id url
  id="$(yt_video_url_id "$input")" || {
    loge "Invalid input: $input"
    return 2
  }
  url="$(yt_video_url_canonical "$id")" || return 2

  dir=${dir%/}
  sub_dir=${sub_dir%/}
  sub_dir=${sub_dir#/}

  local name path
  name="${id}.meta.json"
  path="${dir}/${sub_dir}/${name}"

  printf '%s%s%s%s%s%s%s\n' \
    "$id" "$SEP" "$url" "$SEP" "$name" "$SEP" "$path"
}

__yt_video_meta_download() {
  local url="$1"
  local name="$2"
  local dir="$3"

  # shellcheck disable=SC2154
  "$yt_dlp" \
    --no-warnings \
    --skip-download \
    --dump-json \
    "$url" 2>/dev/null |
  file_write "$name" --dir "$dir"
}

__yt_video_meta_ensure_cache() {
  local url="$1"
  local name="$2"
  local path="$3"
  local refresh="$4"

  if (( ! refresh )) && [[ -s "$path" ]]; then
    logi "Meta exist: $path"
    return 0
  fi
  __yt_video_meta_download "$url" "$name" "${path%/*}" || return 1
  [[ -s "$path" ]] || {
    loge "Meta empty: $path"
    return 1
  }
  logi "Meta written: $path"
}

yt_video_meta_download() {
  local input="${1:?yt_video_meta_download: missing url}"
  shift
  local dir="$YT_CACHE_DIR"
  local sub_dir="$YT_CACHE_SUB_DIR"
  local refresh=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) shift; [[ $# -ge 1 ]] || return 2; dir="$1"; shift ;;
      --sub-dir) shift; [[ $# -ge 1 ]] || return 2; sub_dir="$1"; shift ;;
      --refresh) shift; refresh=1 ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  local derived id url name path
  derived="$(__yt_video_meta_derive \
    "$input" "$dir" "$sub_dir")" || return 2
  IFS="$SEP" read -r id url name path <<< "$derived"
  
  __yt_video_meta_ensure_cache \
    "$url" "$name" "$path" "$refresh" || return 1
}

yt_video_meta() {
  local input="${1:?yt_video_meta: missing url}"
  local field="${2:?yt_video_meta: missing meta field}"
  shift 2
  local dir="$YT_CACHE_DIR"
  local sub_dir="$YT_CACHE_SUB_DIR"
  local refresh=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) shift; [[ $# -ge 1 ]] || return 2; dir="$1"; shift ;;
      --sub-dir) shift; [[ $# -ge 1 ]] || return 2; sub_dir="$1"; shift ;;
      --refresh) shift; refresh=1 ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  local filter
  filter="${YT_VIDEO_META_FILTER_MAP[$field]}"
  [[ -n "$filter" ]] || return 2

  local derived id url name path
  derived="$(__yt_video_meta_derive \
    "$input" "$dir" "$sub_dir")" || return 2
  IFS="$SEP" read -r id url name path <<< "$derived"

  __yt_video_meta_ensure_cache \
    "$url" "$name" "$path" "$refresh" || return 1

  # shellcheck disable=SC2154
  "$jq_bin" -r "$filter" "$path" || return 1
}
