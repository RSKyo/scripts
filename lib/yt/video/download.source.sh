#!/usr/bin/env bash
# Source-only library: lib/yt/video/download
# shellcheck disable=SC1091,2154

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
# [[ -n "${__YT_VIDEO_DOWNLOAD_SOURCED+x}" ]] && return 0
# __YT_VIDEO_DOWNLOAD_SOURCED=1

# --- Dependencies ------------------------------------------------------------

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/letter.source.sh"
source "$LIB_DIR/video.source.sh"

source "$LIB_DIR/yt/const.source.sh"
source "$LIB_DIR/yt/common.source.sh"
source "$LIB_DIR/yt/video/tracklist.source.sh"

# --- Constants ---------------------------------------------------------------

readonly __YT_COOKIE="$LIB_DIR/yt/video/cookies.txt"
readonly __YT_COOKIE_VALID_URL='https://www.youtube.com/watch?v=dQw4w9WgXcQ'

declare -Ar __YT_VIDEO_FORMAT_MAP=(
  [compat]='bv*[vcodec^=avc1][ext=mp4]+ba[ext=m4a]/b[vcodec^=avc1][ext=mp4]'
  [hd]='bv*+ba/b'
)

# --- Public API --------------------------------------------------------------

yt_video_download() {
  local input="${1:?yt_video_tracklist: missing video id or url}"
  local dir="${2:-"$YT_CACHE_DIR"}"
  local mode="${3:-compat}"

  local id url video_name video_path
  yt_video_set_id_url id url "$input" || return 2
  video_name="$(yt_video_meta "$input" title_en "$dir")" || return 1
  video_path="$(__yt_video_exists "$id" "$dir")"

  [[ -z "$video_path" ]] || {
    logi "video exists: $video_path"
    return 0
  }

  __yt_cookie_valid || return 1
  yt_video_tracklist_download "$input" "$dir" || return 1
  
  video_path="${dir%/}/${video_name}"
  video_path="$(__yt_video_download "$url" "$video_path" "$mode")" || 1
  video_metadata_write "$video_path" --id="$id"

  local tracklist_name tracklist_path
  yt_video_tracklist_set_name_path tracklist_name tracklist_path "$input" "$dir"  || return 1

  local start end

  if [[ -s "$tracklist_path" ]]; then
    local -a tracklist=()
    readarray -t tracklist < "$tracklist_path" || return 1

    local total="${#tracklist[@]}"
    local last_idx=$(( total - 1 ))

    start="${tracklist[0]%%"$SEP"*}"
    end="${tracklist[last_idx]%%"$SEP"*}"
  else
    start=0
    end="$(yt_video_meta "$input" duration "$dir")"
  fi

  video_cut "$video_path" "$start" "$end"

  return 0
}

__yt_video_exists() {
  local id="$1"
  local dir="$2"

  local file meta_id

  for file in "$dir"/*; do
    [[ -f "$file" ]] || continue

    case "$file" in
      *.mp4|*.mkv|*.webm) ;;
      *) continue ;;
    esac

    meta_id="$(video_metadata_read "$file" id)" || continue

    [[ "$meta_id" == "$id" ]] && {
      printf '%s\n' "$file"
      return 0
    }
  done

  return 1
}

__yt_cookie_valid() {
  "$yt_dlp" \
    --no-playlist \
    --cookies "$__YT_COOKIE" \
    --print uploader \
    "$__YT_COOKIE_VALID_URL" \
    >/dev/null 2>&1 || {
      loge "YouTube cookie expired"
      return 1
    }
}

__yt_video_download() {
  local url="$1"
  local file_path="$2"
  local mode="${3:-compat}"
  local format="${__YT_VIDEO_FORMAT_MAP[$mode]}"

  [[ -n "$format" ]] || {
    loge "invalid download mode: $mode"
    return 2
  }

  logi "downloading video: $url"

  file_path="$(
  "$yt_dlp" \
    --no-playlist \
    --print after_move:filepath \
    -f "$format" \
    -o "${file_path}.%(ext)s" \
    "$url"
  )" || {
        loge "failed to download video: $url"
        return 1
      }

  logi "video saved: ${file_path}"
  printf '%s\n' "$file_path"
}






