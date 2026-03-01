#!/usr/bin/env bash
# Source-only library: yt.video.tracklist
# shellcheck disable=SC1091

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__YT_VIDEO_TRACKLIST_SOURCED+x}" ]] && return 0
__YT_VIDEO_TRACKLIST_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/description.source.sh"
source "$LIB_DIR/yt/video/tracklist.title.source.sh"
source "$LIB_DIR/yt/video/tracklist.end.source.sh"
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/letter.source.sh"
source "$LIB_DIR/text.source.sh"
source "$LIB_DIR/time.source.sh"

yt_video_tracklist_resolve() {
  local total i line
  local left ts right sec title _

  # --- Extract timestamp lines ---
  # Keep only lines containing timestamps and
  # normalize into structured parts.
  local -a timestamp_lines

  readarray -t timestamp_lines < <(
    text_filter "$TIME_TIMESTAMP_REGEX" |
    text_demath |
    text_expand "$TIME_TIMESTAMP_REGEX"
  )

  total=${#timestamp_lines[@]}
  (( total == 0 )) && return 0

  # --- Locate main tracklist segment ---
  # Find the segment starting at 00:00 and
  # ending at the largest timestamp.
  local -a tracklist_lines
  local start_idx=-1 end_idx=-1
  local zero_idx=-1 max_sec=-1

  for (( i=0; i<total; i++ )); do
    IFS="$STRING_SEP" read -r _ ts _ <<< "${timestamp_lines[i]}"
    ts="${ts//[[:space:]]/}"
    sec=$(time_hms_to_s "$ts")

    (( sec == 0 )) && zero_idx="$i"
    if (( zero_idx >= 0 )) && (( sec > max_sec )); then
      start_idx="$zero_idx"
      end_idx="$i"
      max_sec="$sec"
    fi
  done

  (( start_idx == -1 )) && return 0

  tracklist_lines=("${timestamp_lines[@]:start_idx:$(( end_idx - start_idx + 1 ))}")
  total=${#tracklist_lines[@]}

  # --- Detect timestamp side ---
  # Infer whether timestamp is on left or right.
  local score=0

  for line in "${tracklist_lines[@]}"; do
    IFS="$STRING_SEP" read -r left _ right <<< "$line"

    (( ${#left} > ${#right} )) && (( score++ ))
    (( ${#right} > ${#left} )) && (( score-- ))
  done

  # --- Build internal structure ---
  # <sec><sep><ts><sep><title>
  local -a tracklist

  for line in "${tracklist_lines[@]}"; do
    IFS="$STRING_SEP" read -r left ts right <<< "$line"
    ts="${ts//[[:space:]]/}"
    sec="$(time_hms_to_s "$ts")"
    ts="$(time_s_to_hms "$sec")"

    if (( score > 0 )); then
      tracklist+=("${sec}${STRING_SEP}${ts}${STRING_SEP}${left}")
    else
      tracklist+=("${sec}${STRING_SEP}${ts}${STRING_SEP}${right}")
    fi
  done

  # --- Detect minimal letter start ---
  # Used to remove leading track indices
  # while preserving valid digits in titles.
  local min_pos=0 pos

  for line in "${tracklist[@]}"; do
    IFS="$STRING_SEP" read -r sec ts title <<< "$line"
    pos="$(first_letter_pos "$title")" || continue
    if (( min_pos == 0 )) || (( pos < min_pos )); then
      min_pos="$pos"
      (( min_pos == 1 )) && break
    fi
  done

  (( min_pos == 0 )) && min_pos=1

  # --- Output cleaned tracklist ---
  # Apply title trimming and emit final structure.
  for line in "${tracklist[@]}"; do
    IFS="$STRING_SEP" read -r sec ts title <<< "$line"
    title=$(letter_slice "$title" "$min_pos")
    title=$(letter_trim "$title" "0123456789)）]】")
    
    printf '%s%s%s%s%s\n' "$sec" "$STRING_SEP" "$ts" "$STRING_SEP" "$title"
  done
}


yt_video_tracklist() {
  # --- Params ---
  local input="$1"
  shift
  [[ -n "$input" ]] || return 0

  local auto=0
  local ratio_start=''
  local ratio_end=''
  local support="$YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT"
  local sep_regex=''
  local side=''
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --auto) 
        shift
        auto=1
        ;;
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
      --sep) 
        shift
        [[ $# -ge 1 ]] || return 2
        case "$1" in
          dash_sp|dash|pipe_sp|pipe|slash_sp|slash|dot) \
          sep_regex="${YT_VIDEO_TRACKLIST_TITLE_SEP_MAP[$1]}" ;;
          *) return 2 ;;
        esac
        shift
        ;;
      --side) 
        shift
        [[ $# -ge 1 ]] || return 2
        case "$1" in
          left|right) side="$1" ;;
          *) return 2 ;;
        esac
        shift
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done
  
  # --- Behavior ---
  # --- Load normalized tracklist from description ---
  local -a tracklist
  readarray -t tracklist < <(
    yt_video_description "$input" |
    yt_video_tracklist_resolve
  )

  local total=${#tracklist[@]}
  (( total == 0 )) && return 0

  # --- Auto-detect bilingual separator and side ---
  if (( auto )); then
    sep_regex="$(yt_video_tracklist_title_detect_sep \
      ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} \
      ${support:+--support "$support"} \
      < <(printf '%s\n' "${tracklist[@]}") || return 2
    )"

    if [[ -n "$sep_regex" ]]; then
      side="$(yt_video_tracklist_title_detect_latin_side "$sep_regex" \
        ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} \
        < <(printf '%s\n' "${tracklist[@]}") || return 2
      )"
    fi
  fi

  if [[ -n "$sep_regex" && -n "$side" ]]; then
    printf '%s\n' "${tracklist[@]}" |
    yt_video_tracklist_title_process "$sep_regex" "$side" \
      ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} |
    yt_video_tracklist_end_process "$input"
  else
    printf '%s\n' "${tracklist[@]}" |
    yt_video_tracklist_end_process "$input"
  fi
}
