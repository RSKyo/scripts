#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.title

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
# [[ -n "${__YT_VIDEO_TRACKLIST_TITLE_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_TITLE_SOURCED=1

readonly __YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT=0.6
# shellcheck disable=SC2034
readonly YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT="$__YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT"

# Separator regex priority list (first match wins)
readonly __YT_VIDEO_TRACKLIST_TITLE_SEP_CLASSES=(
  dash_sp
  dash
  pipe_sp
  pipe
  slash_sp
  slash
  dot
)

____yt_video_tracklist_title_get_sep_regex() {
  local -n regex="$1"
  local cls="$2"

  case "$cls" in
    dash_sp)  regex='[[:space:]]+[-–—－][[:space:]]+' ;;
    dash)     regex='[-–—－]' ;;
    pipe_sp)  regex='[[:space:]]+\|[[:space:]]+' ;;
    pipe)     regex='\|' ;;
    slash_sp) regex='[[:space:]]+\/[[:space:]]+' ;;
    slash)    regex='\/' ;;
    dot)      regex='·' ;;
    *) return 2 ;;
  esac
}

__yt_video_tracklist_title_get_sep_regex() {
  local -n _out_regex="$1"
  shift 1
  local _inner_regex
  ____yt_video_tracklist_title_get_sep_regex \
    _inner_regex \
    "$@" || return 2
  _out_regex="$_inner_regex"
}

yt_video_tracklist_title_get_sep_regex() {
  local cls="$1"
  local regex
  __yt_video_tracklist_title_get_sep_regex regex "$cls"
  printf '%s\n' "$regex"
}



yt_video_tracklist_title_detect_sep_class() {
  # --- Params ---
  local ratio_start=''
  local ratio_end=''
  local support="$__YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT"

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
  
  # --- Behavior ---
  local title_stream
  title_stream="$(cat)"

  local cls regex found=''
  for cls in "${__YT_VIDEO_TRACKLIST_TITLE_SEP_CLASSES[@]}"; do
    __yt_video_tracklist_title_get_sep_regex regex "$cls" || continue

    text_supports "$regex" \
      ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} \
      --support "$support" \
    <<< "$title_stream" || continue

    found="$cls"
    break
  done

  printf '%s\n' "$found"
}

yt_video_tracklist_title_detect_latin_side() {
  # --- Params ---
  local sep_class="$1"
  shift 1
  local ratio_start=''
  local ratio_end=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) 
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  # --- Behavior ---
  local sep_regex
  __yt_video_tracklist_title_get_sep_regex sep_regex "$sep_class" || return 2

  local side total=0 lc rc llc rlc score
  local line title_expanded left right _ 
  local -a left_list=()
  local -a right_list=()
  declare -A left_seen=()
  declare -A right_seen=()

  while IFS= read -r line; do
    (( total++ ))

    title_expanded="$(\
      string_expand "$line" "$sep_regex" \
      ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} \
    )"

    IFS="$STRING_SEP" read -r left _ right <<< "$title_expanded"

    left_list+=("$left")
    right_list+=("$right")

    left_seen["$left"]=1
    right_seen["$right"]=1
  done

  lc=${#left_seen[@]}
  rc=${#right_seen[@]}

  if (( lc == total && rc < total )); then
    side="left"
  elif (( rc == total && lc < total )); then
    side="right"
  else
    llc=0 rlc=0 score=0
    for (( i=0; i<total; i++ )); do
      llc=$(letter_count "${left_list[i]}" latin)
      rlc=$(letter_count "${right_list[i]}" latin)
      (( llc > rlc )) && (( score++ ))
      (( rlc > llc )) && (( score-- ))
    done
    (( score >= 0 )) && side="left" || side="right"
  fi

  printf '%s\n' "$side"
}


yt_video_tracklist_title_process() {
  # --- Params ---
  local sep_class="$1"
  local side="$2"
  shift 2
  local ratio_start=''
  local ratio_end=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) 
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  # --- Behavior ---
  local sep_regex
  __yt_video_tracklist_title_get_sep_regex sep_regex "$sep_class" || return 2

  while IFS= read -r line; do
    string_expand_side "$line" "$sep_regex" \
      ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} \
      --side "$side"
  done
}