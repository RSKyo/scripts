#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.end
# shellcheck disable=SC1091,SC2034

# Prevent multiple sourcing
# [[ -n "${__YT_VIDEO_TRACKLIST_DETECT_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_DETECT_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/meta.source.sh"
source "$LIB_DIR/num.source.sh"
source "$LIB_DIR/time.source.sh"
readonly __YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE="$LIB_DIR/yt/video/repeat_keywords.txt"


readonly __YT_VIDEO_TRACKLIST_END_TOL_PCT=30
readonly __YT_VIDEO_TRACKLIST_REPEAT_RATIO=1.5
readonly __YT_VIDEO_TRACKLIST_REPEAT_REGEX='(repeat|repetition|loop|looping|go on|^$)'

yt_video_tracklist_timestamp_is_left() {
  local -n _timestamp_lines_ref="$1"

  local total="${#_timestamp_lines_ref[@]}"
  (( total > 0 )) || return 1

  local score=0
  local line match left right

  for line in "${_timestamp_lines_ref[@]}"; do
    match=
    [[ "$line" =~ $TIME_TIMESTAMP_REGEX ]] || continue
    match="${BASH_REMATCH[0]}"

    # Split by first timestamp occurrence
    left="${line%%"$match"*}"
    right="${line#*"$match"}"

    # Compare length
    (( ${#left}  > ${#right} )) && (( score++ ))
    (( ${#right} > ${#left}  )) && (( score-- ))
  done

  (( score < 0 ))
}

yt_video_tracklist_is_repeat_by_keyword() {
  local -n _tracklist_ref="$1"

  local total="${#_tracklist_ref[@]}"
  (( total > 0 )) || return 1

  local last_idx=$(( total - 1 ))
  local sec ts title
  IFS="$SEP" read -r sec ts title <<< "${_tracklist_ref[last_idx]}"
  [[ "${title,,}" =~ $__YT_VIDEO_TRACKLIST_REPEAT_REGEX ]]
}

yt_video_tracklist_is_repeat_by_duration() {
  local -n _tracklist_ref="$1"
  local duration="$2"
 
  local total="${#_tracklist_ref[@]}"
  (( total > 0 )) || return 1

  local last_idx=$(( total - 1 ))
  local sec ts title
  IFS="$SEP" read -r sec ts title <<< "${_tracklist_ref[last_idx]}"
  # 防止除零
  (( sec > 0 )) || return 1

  num_cmp "$(num_quotient "$duration" "$sec" 1)" \
    ge "$__YT_VIDEO_TRACKLIST_REPEAT_RATIO"
}

yt_video_tracklist_is_repeat() {
  yt_video_tracklist_is_repeat_by_keyword "$1" ||
  yt_video_tracklist_is_repeat_by_duration "$1" "$2"
}

yt_video_tracklist_last_is_song_like() {
  local -n _tracklist_ref="$1"
  local duration="$2"

  local total="${#_tracklist_ref[@]}"
  (( total > 1 )) || return 1

  local last_idx=$(( total - 1 ))
  local sec ts title _
  IFS="$STRING_SEP" read -r sec ts title <<< "${_tracklist_ref[last_idx]}"

  local remain avg den
  den=$(( total - 1 ))
  avg=$(( sec / den ))
  remain=$(( duration - sec ))

  local tol="$__YT_VIDEO_TRACKLIST_END_TOL_PCT"
  local lower=$(( 100 - tol ))
  local upper=$(( 100 + tol ))

  (( remain * 100 >= avg * lower &&
     remain * 100 <= avg * upper ))
}



