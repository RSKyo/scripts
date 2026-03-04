#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.resolve
# shellcheck disable=SC1091

# Prevent multiple sourcing
# [[ -n "${__YT_VIDEO_TRACKLIST_RESOLVE_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_RESOLVE_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/tracklist.detect.source.sh"
source "$LIB_DIR/time.source.sh"

yt_video_tracklist_resolve_time_range() {
  local -n _out_start_ref="$1"
  local -n _out_end_ref="$2"
  local -n _timestamp_lines_ref="$3"

  local total="${#_timestamp_lines_ref[@]}"
  (( total > 0 )) || return 1

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

  _out_start_ref="$start_idx"
  _out_end_ref="$end_idx"
  return 0
}

yt_video_tracklist_resolve_termination() {
  local ref_name="$1"
  local duration="$2"
  local -n _tracklist_ref="$ref_name"

  local total="${#_tracklist_ref[@]}"
  (( total > 0 )) || return 1

  local last_idx=$(( total - 1 ))
  local sec ts _
  IFS="$SEP" read -r sec ts _ <<< "${_tracklist_ref[last_idx]}"

  # --- Repeat ---
  if yt_video_tracklist_is_repeat "$ref_name" "$duration"; then
    _tracklist_ref[last_idx]="${sec}${SEP}${ts}${SEP}@repeat"
    return 0
  fi
  
  # --- Natural termination ---
  if yt_video_tracklist_last_is_song_like "$ref_name" "$duration"; then
      local end_ts
      end_ts=$(time_s_to_hms "$duration")
      _tracklist_ref+=("${duration}${SEP}${end_ts}${SEP}@end")
      return 0
  fi

  # --- Truncated tail ---
  _tracklist_ref[last_idx]="${sec}${SEP}${ts}${SEP}@end"

  return 0
}
