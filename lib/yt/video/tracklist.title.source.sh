#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.title
# shellcheck disable=SC1091

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__YT_VIDEO_TRACKLIST_TITLE_SOURCED+x}" ]] && return 0
__YT_VIDEO_TRACKLIST_TITLE_SOURCED=1

# --- Dependencies ------------------------------------------------------------

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/letter.source.sh"
source "$LIB_DIR/num.source.sh"
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/text.source.sh"

source "$LIB_DIR/yt/const.source.sh"
source "$LIB_DIR/yt/common.source.sh"

# --- Public API --------------------------------------------------------------

yt_video_tracklist_title_align() {
  local -a tracklist
  readarray -t  tracklist

  local total="${#tracklist[@]}"
  (( total > 0 )) || return 0

  local i line sec ts title 
  local pos min_pos=0

  for (( i=0; i<total; i++ )); do
    title="${tracklist[i]##*"$SEP"}"

    pos="$(first_letter_pos "$title")" || continue
    (( pos > 0 )) || continue

    if (( min_pos == 0 )) || (( pos < min_pos )); then
      min_pos="$pos"
      (( min_pos == 1 )) && break
    fi
  done

  (( min_pos == 0 )) && min_pos=1

  for (( i=0; i<total; i++ )); do
    IFS="$SEP" read -r sec ts title <<< "${tracklist[i]}"

    title="$(letter_slice "$title" "$min_pos")"
    title="$(letter_trim "$title" "0123456789)）]】")"

    printf '%s%s%s%s%s\n' "${sec}" "${SEP}" "${ts}" "${SEP}" "${title}"
  done
}

yt_video_tracklist_title_resolve_sep_regex() {
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
 
  local cls _regex _sel_regex
  for cls in "${YT_VIDEO_TRACKLIST_TITLE_SEP_CLASSES[@]}"; do
    _regex="${YT_VIDEO_TRACKLIST_TITLE_SEP_MAP[$cls]}"

    if text_supports "$_regex" --support "$support" <<< "$titles"; then
      logd "title sep class: $cls regex: $_regex"
      _sel_regex="$_regex"
      break
    fi
  done

  [[ -n "$_sel_regex" ]] || return 1

  _sep_regex_ref="$_sel_regex"
}

yt_video_tracklist_title_side_by_uniqueness() {
  local regex="${1:?yt_video_tracklist_title_side_by_uniqueness: missing title sep regex}"

  local -a tracklist
  readarray -t  tracklist

  local total="${#tracklist[@]}"
  (( total > 0 )) || return 0

  local i sec ts title expanded left right
  # --- Uniqueness check ---
  declare -A left_seen=()
  declare -A right_seen=()

  for (( i=0; i<total; i++ )); do
    title="${tracklist[i]##*"$SEP"}"
    expanded="$(string_expand "$title" "$regex")"
    left="${expanded%%"$SEP"*}"
    right="${expanded##*"$SEP"}"

    left_seen["$left"]=1
    right_seen["$right"]=1
  done

  local lc rc
  lc=${#left_seen[@]}
  rc=${#right_seen[@]}

  local side
  if (( lc == total && rc < total )); then
    side='left'
  elif (( rc == total && lc < total )); then
    side='right'
  fi

  [[ -n "$side" ]] || return 1

  # --- Output selected side ---
  printf '%s\n' "${tracklist[@]}" |
  yt_video_tracklist_title_side "$regex" "$side"
}

yt_video_tracklist_title_side_by_bilingual() {
  local regex="${1:?yt_video_tracklist_title_side_by_bilingual: missing title sep regex}"

  local -a tracklist
  readarray -t  tracklist

  local total="${#tracklist[@]}"
  (( total > 0 )) || return 0

  local i sec ts title expanded left right

  # --- Fallback: Latin scoring ---
  local llc=0 rlc=0 llc_latin=0 rlc_latin=0 
  local llt=0 rlt=0 llt_latin=0 rlt_latin=0
  for (( i=0; i<total; i++ )); do
    title="${tracklist[i]##*"$SEP"}"
    expanded="$(string_expand "$title" "$regex")"
    left="${expanded%%"$SEP"*}"
    right="${expanded##*"$SEP"}"

    llc=$(letter_count "$left")
    rlc=$(letter_count "$right")
    llc_latin=$(letter_count "$left" latin)
    rlc_latin=$(letter_count "$right" latin)

    (( llt+=llc ))
    (( rlt+=rlc ))
    (( llt_latin+=llc_latin ))
    (( rlt_latin+=rlc_latin ))
  done

  local l_latin_ratio=0 r_latin_ratio=0 side
  l_latin_ratio=$(num_quotient "$llt_latin" "$llt" 2)
  r_latin_ratio=$(num_quotient "$rlt_latin" "$rlt" 2)

  if num_cmp "$l_latin_ratio" gt '0.7' && num_cmp "$r_latin_ratio" lt '0.3'; then
    side='left'
  elif num_cmp "$r_latin_ratio" gt '0.7' && num_cmp "$l_latin_ratio" lt '0.3'; then
    side='right'
  fi

  [[ -n "$side" ]] || return 1

  # --- Output selected side ---
  printf '%s\n' "${tracklist[@]}" |
  yt_video_tracklist_title_side "$regex" "$side"
}


yt_video_tracklist_title_side() {
  local regex="${1:?yt_video_tracklist_title_side: missing title sep regex}"
  local side="${2:?yt_video_tracklist_title_side: missing side}"
  local line sec ts title

  while IFS= read -r line; do
    IFS="$SEP" read -r sec ts title <<< "$line"

    title="$(string_expand_side "$title" "$regex" --side "$side")"
    title="$(letter_trim "$title" "0123456789)）]】")"

    printf '%s%s%s%s%s\n' \
      "$sec" "$SEP" "$ts" "$SEP" "$title"
  done
}