#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist
# shellcheck disable=SC1091

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_TRACKLIST_SOURCED+x}" ]] && return 0
__YT_VIDEO_TRACKLIST_SOURCED=1

# --- Dependencies ------------------------------------------------------------

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/text.source.sh"

source "$LIB_DIR/yt/const.source.sh"
source "$LIB_DIR/yt/common.source.sh"
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
  text_file "$file_path" || {
    loge "failed to write tracklist cache: $file_path"
    return 1
  }

  logi "tracklist cache saved: $file_path"
}

# --- Public API --------------------------------------------------------------

yt_video_tracklist_download() {
  local input="${1:?yt_video_tracklist: missing video id or url}"
  local dir="${2:-"$YT_CACHE_DIR"}"

  yt_video_meta_download "$input" "$dir" || return 1

  local id url
  yt_video_set_id_url id url "$input" || return 2

  local tracklist_name tracklist_path
  yt_video_tracklist_set_name_path tracklist_name tracklist_path "$input" "$dir"  || return 1

  if [[ ! -s "$tracklist_path" ]]; then
    local description duration
    description="$(yt_video_meta "$input" description "$dir")" || return 1
    duration="$(yt_video_meta "$input" duration "$dir")" || return 1

    __yt_video_tracklist_cache_build \
      "$description" "$duration" "$tracklist_path" || return 1
  else
    logi "tracklist cache: $tracklist_path"
  fi
  
  return 0
}

yt_video_tracklist() {
  local input="${1:?yt_video_tracklist: missing video id or url}"
  local dir="${2:-"$YT_CACHE_DIR"}"

  yt_video_meta_download "$input" "$dir" || return 1

  local id url
  yt_video_set_id_url id url "$input" || return 2

  local tracklist_name tracklist_path
  yt_video_tracklist_set_name_path tracklist_name tracklist_path "$input" "$dir"  || return 1

  if [[ ! -s "$tracklist_path" ]]; then
    local description duration
    description="$(yt_video_meta "$input" description "$dir")" || return 1
    duration="$(yt_video_meta "$input" duration "$dir")" || return 1

    __yt_video_tracklist_cache_build \
      "$description" "$duration" "$tracklist_path" || return 1
  fi

  cat "$tracklist_path"
}
