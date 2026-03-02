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

yt_video_meta() {
  local input="${1:?yt_video_meta: missing url}"
  shift
  local dir="${YT_CACHE_DIR}"
  local sub_dir='meta'
  local field
  local refresh=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) 
        shift
        [[ $# -ge 1 ]] || return 2
        dir="$1"
        shift
        ;;
      --sub-dir) 
        shift
        [[ $# -ge 1 ]] || return 2
        sub_dir="$1"
        shift
        ;;
      --field) 
        shift
        [[ $# -ge 1 ]] || return 2
        field="$1"
        shift
        [[ -n "${YT_VIDEO_META_FILTER_MAP[$field]}" ]] || return 2
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

  dir=${dir%/}
  sub_dir=${sub_dir%/}
  sub_dir=${sub_dir#/}

  local meta_name="${id}.meta.json"
  local meta_path="${dir}/${sub_dir}/$meta_name"

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

  if [[ -n "$field" ]]; then
    local filter field_value
    filter="${YT_VIDEO_META_FILTER_MAP[$field]}"
    field_value="$("$jq_bin" -r "$filter" "$meta_path")" || return 1

    printf '%s\n' "$field_value"
  fi
}
