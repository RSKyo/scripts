#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.resolve
# shellcheck disable=SC1091

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_TRACKLIST_RESOLVE_SOURCED+x}" ]] && return 0
__YT_VIDEO_TRACKLIST_RESOLVE_SOURCED=1

# --- Dependencies ------------------------------------------------------------

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/text.source.sh"
source "$LIB_DIR/time.source.sh"

source "$LIB_DIR/yt/video/tracklist.detect.source.sh"

# --- Public API --------------------------------------------------------------

yt_video_tracklist_resolve() {
  local description="$1"
  local duration="$2"

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
  yt_video_tracklist_time_range start_idx end_idx timestamp_lines || { 
    loge "failed to resolve tracklist time range"; 
    return 1; } 

  local is_left=0
  yt_video_tracklist_timestamp_is_left timestamp_lines && is_left=1

  local -a tracklist=()
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
      tracklist+=("${sec}${SEP}${ts}${SEP}${right}")
    else
      tracklist+=("${sec}${SEP}${ts}${SEP}${left}")
    fi
  done

  printf '%s\n' "${tracklist[@]}"
}

yt_video_tracklist_resolve_termination() {
  local duration="$1"

  local -a tracklist
  readarray -t  tracklist

  local total="${#tracklist[@]}"
  (( total > 0 )) || return 0

  local last_idx=$(( total - 1 ))
  local sec ts _
  IFS="$SEP" read -r sec ts _ <<< "${tracklist[last_idx]}"
  
  if yt_video_tracklist_is_repeat tracklist "$duration"; then
    tracklist[last_idx]="${sec}${SEP}${ts}${SEP}@repeat"

  elif yt_video_tracklist_last_is_song_like tracklist "$duration"; then
    local end_ts
    end_ts=$(time_s_to_hms "$duration")
    tracklist+=("${duration}${SEP}${end_ts}${SEP}@end")

  else
    tracklist[last_idx]="${sec}${SEP}${ts}${SEP}@end"
  fi
  
  printf '%s\n' "${tracklist[@]}"
}