#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist_title

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
# [[ -n "${__YT_VIDEO_TRACKLIST_TITLE_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_TITLE_SOURCED=1

# Separator regex priority list (first match wins)
readonly __YT_VIDEO_TRACKLIST_TITLE_SEP_CLASSES=(
  DASH_SP
  DASH
  PIPE_SP
  PIPE
  SLASH_SP
  SLASH
  DOT
)

__yt_video_tracklist_title_get_regex() {
  local cls="$1"

  case "$cls" in
    DASH_SP)  printf '%s\n' '[[:space:]]+[-–—－][[:space:]]+' ;;
    DASH)     printf '%s\n' '[-–—－]' ;;
    PIPE_SP)  printf '%s\n' '[[:space:]]+\|[[:space:]]+' ;;
    PIPE)     printf '%s\n' '\|' ;;
    SLASH_SP) printf '%s\n' '[[:space:]]+\/[[:space:]]+' ;;
    SLASH)    printf '%s\n' '\/' ;;
    DOT)      printf '%s\n' '·' ;;
    *) return 2 ;;
  esac
}

yt_video_tracklist_detect_title_sep_class() {
  # --- Params ---
  local ratio_start=''
  local ratio_end=''
  local support=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) 
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --support)
        shift
        [[ $# -ge 1 ]] || return 2
        support="$1"
        shift
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done
  
  local title_stream line _ title 

  title_stream="$(
    while IFS= read -r line; do
      IFS="$STRING_SEP" read -r _ title <<< "$line"
      printf '%s\n' "$title"
    done
  )"

  local cls regex found=''
  for cls in "${__YT_VIDEO_TRACKLIST_TITLE_SEP_CLASSES[@]}"; do
    regex="$(__yt_video_tracklist_title_get_regex "$cls")"

    text_supports "$regex" \
      ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} \
      ${support:+--support "$support"} \
      <<< "$title_stream" || continue

    found="$cls"
    break
  done

  printf '%s\n' "$found"
}