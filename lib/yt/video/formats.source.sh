#!/usr/bin/env bash
# Source-only library: lib/yt/video/formats
# shellcheck disable=SC1091

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_FORMATS_SOURCED+x}" ]] && return 0
__YT_VIDEO_FORMATS_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/file.source.sh"
source "$LIB_DIR/yt/video/url.source.sh"

yt_video_formats() {
  local url="${1:?yt_video_formats: missing url}"

  url="$(yt_video_url_canonical "$url")"

  # shellcheck disable=SC2154
  "$yt_dlp" \
  --no-warnings \
  --skip-download \
  --list-formats \
  "$url" 2>/dev/null

  return 0
}

yt_video_formats_write() {
  local url="${1:?yt_video_formats: missing url}"
  local dir="${2:?yt_video_formats: missing output dir}"

  local id
  id="$(yt_video_url_id "$url")"
  [[ -z "$id" ]] && return 0

  printf -v url '%s%s' "$YT_VIDEO_URL_PREFIX" "$id"

  mkdir -p "$dir"

  local file_name="${id}.formats.txt"
  local file_path="$dir/$file_name"

  logd "Fetching meta for: $id"
  
  # shellcheck disable=SC2154
  if "$yt_dlp" \
    --no-warnings \
    --skip-download \
    --list-formats \
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
