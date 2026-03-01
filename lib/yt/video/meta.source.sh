#!/usr/bin/env bash
# Source-only library: yt.video.meta
# shellcheck disable=SC1091,SC2034,SC2154

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_META_SOURCED+x}" ]] && return 0
__YT_VIDEO_META_SOURCED=1

readonly YT_VIDEO_META_TITLE_FILTER='.title // empty'
readonly YT_VIDEO_META_DURATION_FILTER='.duration // 0'
readonly YT_VIDEO_META_DESC_FILTER='.description // empty'
readonly YT_VIDEO_META_FORMATS_FILTER='.formats // empty'

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/file.source.sh"
source "$LIB_DIR/yt/video/url.source.sh"

yt_video_meta() {
  local meta_file="$1"
  local jq_filter="$2"

  [[ -z "$meta_file" || -z "$jq_filter" ]] && return 0
  [[ ! -f "$meta_file" ]] && return 0

  "$jq_bin" -r "$jq_filter" "$meta_file"
}

yt_video_meta_write() {
  local url="${1:?yt_video_meta_write: missing url}"
  local dir="${2:?yt_video_meta_write: missing output dir}"

  local id
  id="$(yt_video_url_id "$url")"
  [[ -z "$id" ]] && return 0

  printf -v url '%s%s' "$YT_VIDEO_URL_PREFIX" "$id"

  mkdir -p "$dir"

  local file_name="${id}.meta.json"
  local file_path="$dir/$file_name"

  logd "Fetching meta for: $id"

  if "$yt_dlp" \
    --no-warnings \
    --skip-download \
    --dump-json \
    "$url" 2>/dev/null |
    file_write "$dir" "$file_name"; then

    if [[ -s "$file_path" ]]; then
      logi "Meta written: $file_path"
    else
      loge "Meta empty: $file_path"
      return 1
    fi

  else
    loge "Meta fetch failed: $url"
    return 1
  fi
}
