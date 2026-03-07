#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist


# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
# [[ -n "${__YT_VIDEO_TRACKLIST_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_SOURCED=1

# --- Dependencies ------------------------------------------------------------
# shellcheck disable=SC1091

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/file.source.sh"

source "$LIB_DIR/yt/video/url.source.sh"
source "$LIB_DIR/yt/video/meta.source.sh"
source "$LIB_DIR/yt/video/tracklist.resolve.source.sh"
source "$LIB_DIR/yt/video/tracklist.title.source.sh"


__yt_video_tracklist_cache_build() {
  local description="$1"
  local duration="$2"
  local file_path="$3"

  logi "resolve video tracklist from description"

  local -a tracklist=()
  readarray -t tracklist < <(
    yt_video_tracklist_resolve "$description" "$duration" |
    yt_video_tracklist_title_align
  )

  local sep_regex
  yt_video_tracklist_title_resolve_sep_regex \
    sep_regex tracklist || return 1

  if [[ -n "$sep_regex" ]]; then
    local -a tmp

    # --- strategy 1: uniqueness ---
    if readarray -t tmp < <(
        printf '%s\n' "${tracklist[@]}" |
        yt_video_tracklist_title_side_by_uniqueness "$sep_regex"
      ) && ((${#tmp[@]})); then
        tracklist=("${tmp[@]}")

    # --- strategy 2: bilingual ---
    elif readarray -t tmp < <(
        printf '%s\n' "${tracklist[@]}" |
        yt_video_tracklist_title_side_by_bilingual "$sep_regex"
      ) && ((${#tmp[@]})); then
        tracklist=("${tmp[@]}")

    # --- strategy 3: fallback ---
    else
      readarray -t tracklist < <(
        printf '%s\n' "${tracklist[@]}" |
        yt_video_tracklist_title_side "$sep_regex" left
      )
    fi
  fi

  readarray -t tracklist < <(
    printf '%s\n' "${tracklist[@]}" |
    yt_video_tracklist_resolve_termination "$duration"
  )


  printf '%s\n' "${tracklist[@]}" |
  file_write "$file_path" || {
    loge "failed to write tracklist cache: $file_path"
    return 1
  }

  logi "tracklist cache saved: $file_path"
}

# --- Public API --------------------------------------------------------------

yt_video_tracklist_download() {
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

  local id file_name file_path
  id="$(yt_video_url_id "$input")" || {
    loge "Invalid input: $input"
    return 2
  }
  file_name="${id}.${YT_CACHE_TRACKLIST_NAME}"
  file_path="${dir%/}/${YT_CACHE_TRACKLIST_FOLDER}/${file_name}"

  if (( refresh )) || [[ ! -s "$file_path" ]]; then
    local args=(--dir "$dir")
    (( refresh )) && args+=(--refresh)

    local description duration
    description="$(yt_video_meta "$input" description "${args[@]}")"
    duration="$(yt_video_meta "$input" duration "${args[@]}")"

    __yt_video_tracklist_cache_build \
      "$description" "$duration" "$file_path" || return 1
  else
    logi "tracklist cache already exists: $file_path"
  fi
  
  return 0
}

yt_video_tracklist() {
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

  local id file_name file_path
  id="$(yt_video_url_id "$input")" || {
    loge "Invalid input: $input"
    return 2
  }
  file_name="${id}.${YT_CACHE_TRACKLIST_NAME}"
  file_path="${dir%/}/${YT_CACHE_TRACKLIST_FOLDER}/${file_name}"

  if (( refresh )) || [[ ! -s "$file_path" ]]; then
    local args=(--dir "$dir")
    (( refresh )) && args+=(--refresh)

    local description duration
    description="$(yt_video_meta "$input" description "${args[@]}")"
    duration="$(yt_video_meta "$input" duration "${args[@]}")"

    __yt_video_tracklist_cache_build \
      "$description" "$duration" "$file_path" || return 1
  fi

  cat "$file_path"
}
