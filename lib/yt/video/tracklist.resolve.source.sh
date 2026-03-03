#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.resolve
# shellcheck disable=SC1091

# Prevent multiple sourcing
# [[ -n "${__YT_VIDEO_TRACKLIST_RESOLVE_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_RESOLVE_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/tracklist.detect.source.sh"
source "$LIB_DIR/time.source.sh"

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
