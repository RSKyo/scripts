#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.video.tracklist

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
# [[ -n "${__YT_VIDEO_TRACKLIST_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_SOURCED=1




# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/description.source.sh"
source "$LIB_DIR/yt/video/duration.source.sh"
source "$LIB_DIR/yt/video/tracklist.title.source.sh"
source "$LIB_DIR/yt/video/tracklist.end.source.sh"
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/letter.source.sh"
source "$LIB_DIR/text.source.sh"
source "$LIB_DIR/num.source.sh"
source "$LIB_DIR/time.source.sh"





__yt_video_tracklist_resolve() {
  local total i line
  local left ts right title _

  # --- Detect timestamp lines and expand ---
  local -a timestamp_lines

  readarray -t timestamp_lines < <(
    text_expand "$TIME_TIMESTAMP_REGEX" < <(
      text_demath < <(
        text_filter "$TIME_TIMESTAMP_REGEX"
      )
    )
  )

  total=${#timestamp_lines[@]}
  (( total == 0 )) && return 0

  # --- Detect tracklist lines (00:00 -> Maximum) ---
  # Select lines from the segment starting at 00:00 with the largest end timestamp.
  local -a tracklist_lines
  local start_idx=-1 end_idx=-1
  local zero_idx=-1 max_sec=-1

  for (( i=0; i<total; i++ )); do
    line="${timestamp_lines[i]}"
    IFS="$STRING_SEP" read -r _ ts _ <<< "$line"
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
  local score=0

  for line in "${tracklist_lines[@]}"; do
    IFS="$STRING_SEP" read -r left _ right <<< "$line"

    (( ${#left} > ${#right} )) && (( score++ ))
    (( ${#right} > ${#left} )) && (( score-- ))
  done

  # --- Normalize and build tracklist ---
  local -a tracklist

  for line in "${tracklist_lines[@]}"; do
    IFS="$STRING_SEP" read -r left ts right <<< "$line"
    
    if (( score > 0 )); then
      tracklist+=("${ts}${STRING_SEP}${left}")
    else
      tracklist+=("${ts}${STRING_SEP}${right}")
    fi
  done

  # --- Detect minimal title start ---
  # Purpose of detecting min_pos:
  # - Remove leading numeric track indices (e.g. "01 ", "1. ", etc.).
  # - Avoid stripping digits that legitimately belong to the title (e.g. "1961 Songs").
  local max_pos=9999
  local min_pos="$max_pos"
  local pos 

  for line in "${tracklist[@]}"; do
    IFS="$STRING_SEP" read -r ts title <<< "$line"

    pos="$(first_letter_pos "$title")" || continue
    (( pos > 0 && pos < min_pos )) && min_pos="$pos"
  done

  (( min_pos == max_pos )) && min_pos=1

  # --- output trimmed tracklist ---
  for line in "${tracklist[@]}"; do
    IFS="$STRING_SEP" read -r ts title <<< "$line"

    ts="${ts//[[:space:]]/}"
    title=$(letter_slice "$title" "$min_pos")
    title=$(letter_trim "$title" "0123456789(（)）[【]】")
    
    printf '%s%s%s\n' "$ts" "$STRING_SEP" "$title"
  done
}





# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_video_tracklist() {
  # --- Params ---
  local input="$1"
  shift
  [[ -n "$input" ]] || return 0

  local auto=0
  local ratio_start=''
  local ratio_end=''
  local support="$YT_VIDEO_TRACKLIST_TITLE_SEP_SUPPORT"
  local sep_class=''
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
          dash_sp|dash|pipe_sp|pipe|slash_sp|slash|dot) sep_class="$1" ;;
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

  
  local -a tracklist
  local total

  readarray -t tracklist < <(
    yt_video_description "$input" |
    __yt_video_tracklist_resolve
  )

  total=${#tracklist[@]}
  (( total == 0 )) && return 0

  local -a ts_list=()
  local -a title_list=()
  local line ts title

  for line in "${tracklist[@]}"; do
    IFS="$STRING_SEP" read -r ts title <<< "$line"
    ts_list+=("$ts")
    title_list+=("$title")
  done



  if (( auto == 1 )); then
    sep_class="$(yt_video_tracklist_title_detect_sep_class \
      ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} \
      ${support:+--support "$support"} \
      < <(printf '%s\n' "${title_list[@]}") || return 2
    )"

    if [[ -n "$sep_class" ]]; then
      side="$(yt_video_tracklist_title_detect_latin_side "$sep_class" \
        ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} \
        < <(printf '%s\n' "${title_list[@]}") || return 2
      )"
    fi
  fi

  if [[ -n "$sep_class" && -n "$side" ]]; then
    local -a side_title_list
    readarray -t side_title_list < <(
      yt_video_tracklist_title_process "$sep_class" "$side" \
        ${ratio_start:+${ratio_end:+--window "$ratio_start" "$ratio_end"}} \
        < <(printf '%s\n' "${title_list[@]}") || return 2
    )

    for (( i=0; i<total; i++ )); do
      ts="${ts_list[i]}"
      title="${side_title_list[i]}"
      tracklist[i]="${ts}${STRING_SEP}${title}"
    done
  fi

  printf '%s\n' "${tracklist[@]}" | 
  yt_video_tracklist_end_process "$input"

  
  
}
