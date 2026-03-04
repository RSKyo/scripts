#!/usr/bin/env bash
# Source-only library: yt.video.tracklist
# shellcheck disable=SC1091

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
# [[ -n "${__YT_VIDEO_TRACKLIST_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/url.source.sh"
source "$LIB_DIR/yt/video/meta.source.sh"
source "$LIB_DIR/yt/video/tracklist.detect.source.sh"
source "$LIB_DIR/yt/video/tracklist.resolve.source.sh"
source "$LIB_DIR/yt/video/tracklist.title.source.sh"
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/letter.source.sh"
source "$LIB_DIR/text.source.sh"
source "$LIB_DIR/time.source.sh"



yt_video_tracklist_output() {
  local dir="$1"
  local id="$2"

  if [[ -n "$dir" && -n "$id" ]]; then
    mkdir -p "$dir" || return 1
    tee "$dir/${id}.tracklist.txt"
  else
    cat
  fi
}


yt_video_tracklist() {
  # --- Params ---
  local input="$1"
  shift
  [[ -n "$input" ]] || return 0


  local support="$YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT"

  
  local dir="$YT_CACHE_DIR"
  local refresh=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) shift; [[ $# -ge 1 ]] || return 2; dir="$1"; shift ;;
      --refresh) shift; refresh=1 ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  # --- description and duration ---
  local args=(--dir "$dir")
  (( refresh )) && args+=(--refresh)

  local description duration
  description="$(yt_video_meta "$input" description "${args[@]}")"
  duration="$(yt_video_meta "$input" duration "${args[@]}")"

  # --- resolve tracklist ---
  local -a tracklist=()
  yt_video_tracklist_resolve tracklist "$description" "$duration" || {
    loge 'failed to resolve tracklist'
  }

  printf '%s\n' "${tracklist[@]}"


  
#   # --- Behavior ---
#   # --- Load normalized tracklist from description ---
#   local -a tracklist
#   readarray -t tracklist < <(
#     yt_video_description "$input" |
#     yt_video_tracklist_resolve
#   )

#   local total=${#tracklist[@]}
#   (( total == 0 )) && return 0

#   # --- Auto-detect bilingual separator and side ---
#   if (( auto )); then
#     sep_regex="$(yt_video_tracklist_title_detect_sep \
#       ${support:+--support "$support"} \
#       < <(printf '%s\n' "${tracklist[@]}") || return 2
#     )"

#     if [[ -n "$sep_regex" ]]; then
#       side="$(yt_video_tracklist_title_detect_latin_side "$sep_regex" \
#         < <(printf '%s\n' "${tracklist[@]}") || return 2
#       )"
#     fi
#   fi

#   local id
#   id=$(yt_video_id "$input")

#   if [[ -n "$sep_regex" && -n "$side" ]]; then
#     printf '%s\n' "${tracklist[@]}" |
#     yt_video_tracklist_title_process "$sep_regex" "$side" |
#     yt_video_tracklist_end_process "$input" |
#     yt_video_tracklist_output "$out" "$id"
#   else
#     printf '%s\n' "${tracklist[@]}" |
#     yt_video_tracklist_end_process "$input" |
#     yt_video_tracklist_output "$out" "$id"
#   fi
}
