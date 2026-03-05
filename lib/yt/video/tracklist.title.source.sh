#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.title

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
# [[ -n "${__YT_VIDEO_TRACKLIST_TITLE_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_TITLE_SOURCED=1

readonly YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT=0.6

# Separator regex priority list (first match wins)
readonly YT_VIDEO_TRACKLIST_TITLE_SEP_CLASSES=(
  dash_sp
  dash
  pipe_sp
  pipe
  slash_sp
  slash
  dot
)

declare -Ar YT_VIDEO_TRACKLIST_TITLE_SEP_MAP=(
  [dash_sp]='[[:space:]]+[-–—－][[:space:]]+'
  [dash]='[-–—－]'
  [pipe_sp]='[[:space:]]+\|[[:space:]]+'
  [pipe]='\|'
  [slash_sp]='[[:space:]]+\/[[:space:]]+'
  [slash]='\/'
  [dot]='·'
)

# -------------------------------------------------
# Public API (stdout interface)
# -------------------------------------------------

yt_video_tracklist_title_align() {
  local -n _tracklist_ref="$1"
  
  local -a _inner_tracklist=("$_tracklist_ref[@]")

  ____yt_video_tracklist_resolve_title_align \
    _inner_tracklist || return

  _tracklist_ref=("$_inner_tracklist[@]")
}

____yt_video_tracklist_title_align() {
  local -n _tracklist_ref="$1"

  local total="${#_tracklist_ref[@]}"
  (( total > 0 )) || return 0

  local i line sec ts title 
  local pos min_pos=0

  for (( i=0; i<total; i++ )); do
    title="${_tracklist_ref[i]##*"$SEP"}"

    pos="$(first_letter_pos "$title")" || continue
    (( pos > 0 )) || continue

    if (( min_pos == 0 )) || (( pos < min_pos )); then
      min_pos="$pos"
      (( min_pos == 1 )) && break
    fi
  done

  (( min_pos == 0 )) && min_pos=1

  for (( i=0; i<total; i++ )); do
    IFS="$SEP" read -r sec ts title <<< "${_tracklist_ref[i]}"

    title="$(letter_slice "$title" "$min_pos")"
    title="$(letter_trim "$title" "0123456789)）]】")"

    _tracklist_ref[i]="${sec}${SEP}${ts}${SEP}${title}"
  done
}



# Detect which side contains Latin text
# stdin : <sec><sep><ts><sep><title>
# stdout: left | right
____yt_video_tracklist_resolve_title() {
  local _ref_name="$1"
  local -n _tracklist_ref="$_ref_name"
  local sep_regex="$2"

  local total="${#_tracklist_ref[@]}"
  (( total > 0 )) || return 0

  yt_video_tracklist_resolve_title_align "$_ref_name"

  # --- Uniqueness check ---
  local line title_expanded left right _ 
  declare -A left_seen=()
  declare -A right_seen=()

  for line in "${_tracklist_ref[@]}"; do
    title_expanded="$(string_expand "${line##*"$SEP"}" "$sep_regex")"
    IFS="$SEP" read -r left _ right <<< "$title_expanded"

    left_seen["$left"]=1
    right_seen["$right"]=1
  done

  # --- Decide by uniqueness ---
  local lc rc
  lc=${#left_seen[@]}
  rc=${#right_seen[@]}

  (( lc == total && rc < total )) && return 0
  (( rc == total && lc < total )) && return 1

  # --- Fallback: Latin scoring ---
  local llc=0 rlc=0 score=0
  for line in "${_tracklist_ref[@]}"; do
    title_expanded="$(string_expand "${line##*"$SEP"}" "$sep_regex")"
    IFS="$SEP" read -r left _ right <<< "$title_expanded"

    llc=$(letter_count "$left" latin)
    rlc=$(letter_count "$right" latin)
    (( llc > rlc )) && (( score++ ))
    (( rlc > llc )) && (( score-- ))
  done

  (( score >= 0 )) &&  return 0 || return 1
}

# Normalize title by detected side
# stdin : <sec><sep><ts><sep><title>
# stdout: <sec><sep><ts><sep><title>
yt_video_tracklist_title_process() {
  # --- Params ---
  local regex="$1"
  local side="$2"

  # --- Process lines ---
  local sec ts title title_side
  while IFS= read -r line; do
    IFS="$STRING_SEP" read -r sec ts title <<< "$line"

    title_side="$(string_expand_side "$title" "$regex" \
      --side "$side")"

    printf '%s%s%s%s%s\n' \
      "$sec" "$STRING_SEP" "$ts" "$STRING_SEP" "$title_side"
  done
}