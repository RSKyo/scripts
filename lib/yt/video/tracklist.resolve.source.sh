#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.resolve
# shellcheck disable=SC1091,SC2178

# Prevent multiple sourcing
# [[ -n "${__YT_VIDEO_TRACKLIST_RESOLVE_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_RESOLVE_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/tracklist.detect.source.sh"
source "$LIB_DIR/time.source.sh"

____yt_video_tracklist_resolve_time_range() {
  local -n _start_idx_ref="$1"
  local -n _end_idx_ref="$2"
  local -n _timestamp_lines_ref="$3"

  local total="${#_timestamp_lines_ref[@]}"
  (( total > 0 )) || return 0

  local start_idx=-1 end_idx=-1
  local zero_idx=-1 max_sec=-1

  local i line match ts sec 
  for (( i=0; i<total; i++ )); do
    line="${_timestamp_lines_ref[i]}"

    match=
    [[ "$line" =~ $TIME_TIMESTAMP_REGEX ]] && match="${BASH_REMATCH[0]}"
    [[ -n "$match" ]] || continue

    ts="${match//[[:space:]]/}"
    ts="${ts//：/:}"
    sec="$(time_hms_to_s "$ts")"

    (( sec == 0 )) && zero_idx="$i"
    if (( zero_idx >= 0 )) && (( sec > max_sec )); then
      start_idx="$zero_idx"
      end_idx="$i"
      max_sec="$sec"
    fi
  done

  (( start_idx >= 0 )) || return 1

  _start_idx_ref="$start_idx"
  _end_idx_ref="$end_idx"
  return 0
}

____yt_video_tracklist_resolve_termination() {
  local _ref_name="$1"
  local -n _tracklist_ref="$_ref_name"
  local duration="$2"
  

  local total="${#_tracklist_ref[@]}"
  (( total > 0 )) || return 0

  local last_idx=$(( total - 1 ))
  local sec ts _
  IFS="$SEP" read -r sec ts _ <<< "${_tracklist_ref[last_idx]}"

  # --- Repeat ---
  if yt_video_tracklist_is_repeat "$_ref_name" "$duration"; then
    _tracklist_ref[last_idx]="${sec}${SEP}${ts}${SEP}@repeat"
    return 0
  fi
  
  # --- Natural termination ---
  if yt_video_tracklist_last_is_song_like "$_ref_name" "$duration"; then
      local end_ts
      end_ts=$(time_s_to_hms "$duration")
      _tracklist_ref+=("${duration}${SEP}${end_ts}${SEP}@end")
      return 0
  fi

  # --- Truncated tail ---
  _tracklist_ref[last_idx]="${sec}${SEP}${ts}${SEP}@end"

  return 0
}

____yt_video_tracklist_resolve() {
  local -n _tracklist_ref="$1"
  local description="$2"
  local duration="$3"

  local -a timestamp_lines
  readarray -t timestamp_lines < <(
    printf '%s\n' "$description" |
    text_filter "$TIME_TIMESTAMP_REGEX" | 
    text_demath
  )

  (( ${#timestamp_lines[@]} == 0 )) && {
    logi "no timestamp lines found"
    return 0
  }

  local start_idx end_idx
  yt_video_tracklist_resolve_time_range \
    start_idx end_idx timestamp_lines || {
      loge "failed to resolve tracklist time range start: $start_idx end: $end_idx"
      return 1
  }

  local is_left=0
  yt_video_tracklist_timestamp_is_left timestamp_lines && is_left=1

  _tracklist_ref=()
  local i line expanded
  local left ts right sec

  for (( i=start_idx; i<=end_idx; i++ )); do
    line="${timestamp_lines[i]}"
    expanded="$(string_expand "$line" "$TIME_TIMESTAMP_REGEX")"
    IFS="$SEP" read -r left ts right <<< "$expanded"

    ts="${ts//[[:space:]]/}"
    ts="${ts//：/:}"
    sec="$(time_hms_to_s "$ts")"
    ts="$(time_s_to_hms "$sec")"

    (( sec > duration )) && continue

    if (( is_left )); then
      _tracklist_ref+=("${sec}${SEP}${ts}${SEP}${right}")
    else
      _tracklist_ref+=("${sec}${SEP}${ts}${SEP}${left}")
    fi
  done
}

____yt_video_tracklist_resolve_title_sep_regex() {
  local -n _sep_regex_ref="$1"
  local -n _tracklist_ref="$2"
  local support="${3:-$YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT}"

  local total="${#_tracklist_ref[@]}"
  (( total > 0 )) || return 0

  local titles line
  titles="$(
    for line in "${_tracklist_ref[@]}"; do
      printf '%s\n' "${line##*"$SEP"}"
    done
  )"
 
  local cls regex sel_regex
  for cls in "${YT_VIDEO_TRACKLIST_TITLE_SEP_CLASSES[@]}"; do
    regex="${YT_VIDEO_TRACKLIST_TITLE_SEP_MAP[$cls]}"

    if text_supports "$regex" --support "$support" <<< "$titles"; then
      sel_regex="$regex"
      break
    fi
  done

  [[ -n "$sel_regex" ]] || return 1
  _sep_regex_ref="$sel_regex"
}

yt_video_tracklist_resolve_time_range() {
  local -n _start_idx_ref="$1"
  local -n _end_idx_ref="$2"
  local -n _timestamp_lines_ref="$3"

  local _inner_start_idx="$_start_idx_ref"
  local _inner_end_idx="$_end_idx_ref"
  local -a _inner_timestamp_lines=("${_timestamp_lines_ref[@]}")

  ____yt_video_tracklist_resolve_time_range \
    _inner_start_idx \
    _inner_end_idx \
    _inner_timestamp_lines || return

  _start_idx_ref="$_inner_start_idx"
  _end_idx_ref="$_inner_end_idx"
}

yt_video_tracklist_resolve_termination() {
  local _ref_name="$1"
  local -n _tracklist_ref="$_ref_name"
  local duration="$2"

  local -a _inner_tracklist=("${_tracklist_ref[@]}")

  ____yt_video_tracklist_resolve_termination \
    _inner_tracklist \
    "$duration" || return

  _tracklist_ref=("${_inner_tracklist[@]}")
}

yt_video_tracklist_resolve() {
  local -n _tracklist_ref="$1"
  local description="$2"
  local duration="$3"

  local -a _inner_tracklist=("${_tracklist_ref[@]}")

  ____yt_video_tracklist_resolve \
    _inner_tracklist \
    "$description" \
    "$duration" || return

  _tracklist_ref=("${_inner_tracklist[@]}")
}

yt_video_tracklist_resolve_title_sep_regex() {
  local -n _sep_regex_ref="$1"
  local -n _tracklist_ref="$2"
  local support="${3:-$YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT}"

  local _inner_sep_regex="$_sep_regex_ref"
  local _inner_tracklist=("${_tracklist_ref[@]}")

  ____yt_video_tracklist_resolve_sep \
    _inner_sep_regex \
    _inner_tracklist \
    "$support" || return

  _sep_regex_ref="$_inner_sep_regex"
}