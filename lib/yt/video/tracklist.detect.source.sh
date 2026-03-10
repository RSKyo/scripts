#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.detect
# shellcheck disable=SC1091

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_TRACKLIST_DETECT_SOURCED+x}" ]] && return 0
__YT_VIDEO_TRACKLIST_DETECT_SOURCED=1

# --- Dependencies ------------------------------------------------------------

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/num.source.sh"
source "$LIB_DIR/time.source.sh"

source "$LIB_DIR/yt/const.source.sh"
source "$LIB_DIR/yt/common.source.sh"
source "$LIB_DIR/yt/video/meta.source.sh"

# --- Public API --------------------------------------------------------------

yt_video_tracklist_time_range() {
  local -n _start_idx_ref="$1"
  local -n _end_idx_ref="$2"
  local -n _timestamp_lines_ref="$3"

  local total="${#_timestamp_lines_ref[@]}"
  (( total > 0 )) || return 0

  local _start_idx=-1 _end_idx=-1
  local zero_idx=-1 max_sec=-1

  local i ts sec 
  for (( i=0; i<total; i++ )); do
    [[ "${_timestamp_lines_ref[i]}" =~ $TIMESTAMP_REGEX ]] || continue

    ts="${BASH_REMATCH[0]}"
    [[ -n "$ts" ]] || continue

    ts="${ts//[[:space:]]/}"
    ts="${ts//：/:}"
    sec="$(time_hms_to_s "$ts")"

    (( sec == 0 )) && zero_idx="$i"
    if (( zero_idx >= 0 )) && (( sec > max_sec )); then
      _start_idx="$zero_idx"
      _end_idx="$i"
      max_sec="$sec"
    fi
  done

  (( _start_idx >= 0 )) || return 1

  _start_idx_ref="$_start_idx"
  _end_idx_ref="$_end_idx"
}

yt_video_tracklist_timestamp_is_left() {
  local -n _timestamp_lines_ref="$1"

  local total="${#_timestamp_lines_ref[@]}"
  (( total >= 2 )) || return 1 # 增加最小样本

  local score=0
  local line match left right

  for line in "${_timestamp_lines_ref[@]}"; do
    [[ "$line" =~ $TIMESTAMP_REGEX ]] || continue
    match="${BASH_REMATCH[0]}"
    [[ -n "$match" ]] || continue

    # Split by first timestamp occurrence
    left="${line%%"$match"*}"
    right="${line#*"$match"}"

    # Compare length
    (( ${#left}  > ${#right} )) && (( score++ ))
    (( ${#right} > ${#left}  )) && (( score-- ))
  done

  (( score <= 0 ))
}

yt_video_tracklist_is_repeat_by_keyword() {
  local -n _tracklist_ref="$1"

  local total="${#_tracklist_ref[@]}"
  (( total > 0 )) || return 1

  local last_idx=$(( total - 1 ))
  local title="${_tracklist_ref[last_idx]##*"$SEP"}"
  [[ "${title,,}" =~ $YT_VIDEO_TRACKLIST_REPEAT_REGEX ]]
}

yt_video_tracklist_is_repeat_by_duration() {
  local -n _tracklist_ref="$1"
  local duration="$2"

  local total="${#_tracklist_ref[@]}"
  (( total > 0 )) || return 1

  local last_idx=$(( total - 1 ))
  local sec="${_tracklist_ref[last_idx]%%"$SEP"*}"
  # 防止除零
  (( sec > 0 )) || return 1

  num_cmp "$(num_quotient "$duration" "$sec" 1)" \
    ge "$YT_VIDEO_TRACKLIST_REPEAT_RATIO"
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
  local sec="${_tracklist_ref[last_idx]%%"$SEP"*}"

  local remain avg den
  den=$(( total - 1 )) # total > 1 防止除零
  avg=$(( sec / den ))
  remain=$(( duration - sec ))

  local tol="$YT_VIDEO_TRACKLIST_END_TOL_PCT"
  local lower=$(( 100 - tol ))
  local upper=$(( 100 + tol ))

  (( remain * 100 >= avg * lower &&
     remain * 100 <= avg * upper ))
}
