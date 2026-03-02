#!/usr/bin/env bash
# Source-only library: yt.video.meta
# shellcheck disable=SC1091,SC2034,SC2154

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_META_SOURCED+x}" ]] && return 0
__YT_VIDEO_META_SOURCED=1

declare -Ar YT_VIDEO_META_FILTER_MAP=(
  [title]='.title // empty'
  [duration]='.duration // 0'
  [description]='.description // empty'
)

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/file.source.sh"
source "$LIB_DIR/yt/video/url.source.sh"

yt_video_meta_download() {
  local input="${1:?yt_video_meta_download: missing id or url}"
  shift
  local meta_dir="${YT_CACHE_DIR}/meta"
  local refresh=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) 
        shift
        [[ $# -ge 1 ]] || return 2
        meta_dir="$1"
        shift
        ;;
      --refresh) 
        shift
        refresh=1
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  local id url
  id="$(yt_video_url_id "$input")" || {
    loge "Invalid input: $input"
    return 2
  }
  url="$(yt_video_url_canonical "$id")" || return 2

  local meta_name="${id}.meta.json"
  local meta_path="$meta_dir/$meta_name"

  if (( refresh )) || [[ ! -s "$meta_path" ]]; then
    "$yt_dlp" \
      --no-warnings \
      --skip-download \
      --dump-json \
      "$url" 2>/dev/null |
    file_write "$meta_name" --dir "$meta_dir"

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
  local field="${2:?yt_video_meta: missing field}"
  shift 2
  local meta_dir="${YT_CACHE_DIR}/meta"
  local refresh=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) 
        shift
        [[ $# -ge 1 ]] || return 2
        meta_dir="$1"
        shift
        ;;
      --refresh) 
        shift
        refresh=1
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  local id url
  id="$(yt_video_url_id "$input")" || {
    loge "Invalid input: $input"
    return 2
  }
  url="$(yt_video_url_canonical "$id")" || return 2

  local filter
  filter="${YT_VIDEO_META_FILTER_MAP[$field]}"
  [[ -n "$filter" ]] || {
    loge "Unknown meta field: $field"
    return 2
  }

  local meta_name="${id}.meta.json"
  local meta_path="$meta_dir/$meta_name"

  if (( refresh )) || [[ ! -s "$meta_path" ]]; then
    local args=(--dir "$meta_dir")
    (( refresh )) && args+=(--refresh)

    yt_video_meta_download "$url" "${args[@]}"
  fi

  local field_value
  field_value="$("$jq_bin" -r "$filter" "$meta_path")" || return 1

  printf '%s\n' "$field_value"
}
