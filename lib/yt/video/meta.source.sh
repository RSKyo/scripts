#!/usr/bin/env bash
# Source-only library: yt.video.meta
# shellcheck disable=SC1091,SC2034,SC2154

# Prevent multiple sourcing
# [[ -n "${__YT_VIDEO_META_SOURCED+x}" ]] && return 0
# __YT_VIDEO_META_SOURCED=1

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
  local input="${1:?yt_video_meta_path: missing url}"
  shift
  local dir="${YT_CACHE_DIR}"
  local sub_dir='meta'

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) shift; [[ $# -ge 1 ]] || return 2; dir="$1"; shift ;;
      --sub-dir) shift; [[ $# -ge 1 ]] || return 2; sub_dir="$1"; shift ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  local id url
  id="$(yt_video_url_id "$input")" || { loge "Invalid input: $input"; return 2; }
  url="$(yt_video_url_canonical "$id")" || return 2

  dir=${dir%/}
  sub_dir=${sub_dir%/}
  sub_dir=${sub_dir#/}

  local name path
  name="${id}.meta.json"
  path="${dir}/${sub_dir}/${name}"

  local sep=$'\x1f'
  printf '%s%s%s%s%s%s%s\n' "$id" "$STRING_SEP" "$url" "$STRING_SEP" "$name" "$STRING_SEP" "$path" 
}

yt_video_meta_download() {
  local input="${1:?yt_video_meta_download: missing url}"
  shift
  local dir="${YT_CACHE_DIR}"
  local sub_dir='meta'
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


  local id url name path
  IFS=$'\x1f' read -r id url name path < <(\
    __yt_video_meta_derive "$input" \
      --dir "$dir" --sub-dir "$sub_dir" \
  ) || return 2
  
  meta_path="$(__yt_video_meta_derive "$id" --dir "$dir" --sub-dir "$sub_dir")" || return $?


  local id url meta_path meta_name

  id="$(yt_video_url_id "$input")" || { loge "Invalid input: $input"; return 2; }
  url="$(yt_video_url_canonical "$id")" || return 2
  
  meta_name="${meta_path##*/}"

  if (( refresh )) || [[ ! -s "$meta_path" ]]; then
    "$yt_dlp" \
      --no-warnings \
      --skip-download \
      --dump-json \
      "$url" 2>/dev/null |
    file_write "$meta_name" --dir "${dir}/${sub_dir}"

    if [[ -s "$meta_path" ]]; then
      logi "Meta written: $meta_path"
    else
      loge "Meta empty: $meta_path"
      return 1
    fi
  else
    logi "Meta exist: $meta_path"
  fi
}

yt_video_meta() {
  local input="${1:?yt_video_meta: missing url}"
  local field="${2:?yt_video_meta: missing meta field}"
  shift 2
  local dir="${YT_CACHE_DIR}"
  local sub_dir='meta'
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

  [[ -n "${YT_VIDEO_META_FILTER_MAP[$field]}" ]] || return 2

  yt_video_meta_download "$input" \
    --dir "$dir" \
    --sub-dir "$sub_dir" \
    --refresh "$refresh" || return $?

  local meta_path filter
  meta_path="$(yt_video_meta_path "$input" --dir "$dir" --sub-dir "$sub_dir")" || return $?
  filter="${YT_VIDEO_META_FILTER_MAP[$field]}"

  "$jq_bin" -r "$filter" "$meta_path" || return 1
}
