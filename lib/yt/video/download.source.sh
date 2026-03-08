#!/usr/bin/env bash
# Source-only library: lib/yt/video/download
# shellcheck disable=SC1091

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
# [[ -n "${__YT_VIDEO_DOWNLOAD_SOURCED+x}" ]] && return 0
# __YT_VIDEO_DOWNLOAD_SOURCED=1

# --- Dependencies ------------------------------------------------------------

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/letter.source.sh"

source "$LIB_DIR/yt/video/tracklist.source.sh"

# --- Constants ---------------------------------------------------------------

readonly __YT_VIDEO_COOKIE="$LIB_DIR/yt/video/cookies.txt"


# --- Public API --------------------------------------------------------------

yt_video_download() {
  local input="${1:?yt_video_tracklist: missing url}"
  shift
  local dir="$YT_CACHE_DIR"
  local refresh=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) shift; [[ $# -ge 1 ]] || return 2; dir="$1"; shift ;;
      --refresh) shift; refresh=1 ;;
      --) shift; break ;;
      *) { loge "Invalid args: $1"
        return 2; } ;;
    esac
  done

  

  __yt_video_cookie_valid || return 1

  local -a opts=(--dir "$dir")
  (( refresh )) && opts+=(--refresh)
  yt_video_tracklist_download "$input" "${opts[@]}" || return 1


local id url tracklist_name tracklist_path
  IFS="$SEP" read -r id url tracklist_name tracklist_path \
    < <(yt_video_tracklist_cache_info "$input" "$dir")

  local -a tracklist=()
  readarray -t tracklist < "$tracklist_path" || return 1

  

  local total="${#tracklist[@]}"
  local last_idx=$(( total - 1 ))
  local start="${tracklist[0]%%"$SEP"*}"
  local end="${tracklist[last_idx]%%"$SEP"*}"

  local video_title file_path
  video_title="$(yt_video_meta "$input" title_en --dir "$dir")"
  file_path="${dir%/}/${video_title}.mp4"

  if (( refresh )) || [[ ! -f "$file_path" ]]; then
    __yt_video_download_avc1 "$url" "$start" "$end" "$file_path"
  else
    logi "video exists: $file_path"
  fi

  return 0
}

__yt_video_cookie_valid() {
  "$yt_dlp" \
    --cookies "$__YT_VIDEO_COOKIE" \
    --print uploader \
    https://www.youtube.com/watch?v=dQw4w9WgXcQ \
    >/dev/null 2>&1 || {
      loge "YouTube cookie expired"
      return 1
    }
}

__yt_video_download_avc1() {
  local url="$1"
  local start="$2"
  local end="$3"
  local file_path="$4"

  logi "downloading video: $url"

  "$yt_dlp" \
    --no-playlist \
    --cookies "$__YT_VIDEO_COOKIE" \
    -S "res,fps" \
    -f "bv*[vcodec^=avc1][ext=mp4]+ba[ext=m4a]/b[vcodec^=avc1][ext=mp4]" \
    -o "${file_path%.*}.%(ext)s" \
    "$url" || {
      loge "failed to download video: $url"
      return 1
  }

  logi "video saved: ${file_path}"
}




