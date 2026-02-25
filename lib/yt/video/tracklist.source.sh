#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.video.tracklist

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
# [[ -n "${__YT_VIDEO_TRACKLIST_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_SOURCED=1

# Separator regex priority list (first match wins)
readonly __YT_VIDEO_TRACKLIST_TITLE_SEP_REGEXES=(
  '[[:space:]]+[-–—－][[:space:]]+'
  '[-–—－]'
  '[[:space:]]+\|[[:space:]]+'
  '\|'
  '[[:space:]]+\/[[:space:]]+'
  '\/'
  '·'
)

__YT_VIDEO_TRACKLIST_REPEAT_REGEX=
__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_MTIME=
readonly __YT_TRACKLIST_END_TOL_PCT=30

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/description.source.sh"
source "$LIB_DIR/yt/video/duration.source.sh"
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/letter.source.sh"
source "$LIB_DIR/text.source.sh"
source "$LIB_DIR/num.source.sh"
source "$LIB_DIR/time.source.sh"

readonly __YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE="$LIB_DIR/yt/video/repeat_keywords.txt"

yt_video_tracklist_resolve() {
  local total i line
  local left ts right title _

  # --- Detect timestamp lines and expand ---
  local -a timestamp_lines

  readarray -t timestamp_lines < <(
    text_filter_expand "$TIME_TIMESTAMP_REGEX"
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

yt_video_tracklist_bilingual_process() {
  local total i line
  local ts title left match right _

  # --- Stage 1: Load input ---
  # Read full tracklist (timestamp + title) from stdin
  local -a tracklist
  readarray -t tracklist
  total=${#tracklist[@]}
  (( total == 0 )) && return 0

  # --- Stage 2: Detect separator ---
  # Identify a bilingual separator regex supported
  # by the majority of titles
  local titlelist_stream regex sep_regex
  titlelist_stream="$(
    for line in "${tracklist[@]}"; do
      IFS="$STRING_SEP" read -r _ title <<< "$line"
      printf '%s\n' "$title"
    done
  )"

  for regex in "${__YT_VIDEO_TRACKLIST_TITLE_SEP_REGEXES[@]}"; do
    text_supports "$regex" --support 0.6 <<< "$titlelist_stream" || continue
    sep_regex="$regex"
    break
  done

  # If no separator detected, output original tracklist
  [[ -z "$sep_regex" ]] && { printf '%s\n' "${tracklist[@]}" ; return 0; }

  # --- Stage 3: Expand titles ---
  # Split titles into left / match / right components
  local -a titlelist
  readarray -t titlelist < <(
    text_expand "$sep_regex" <<< "$titlelist_stream"
  )

  # --- Stage 4: Analyze split structure ---
  # Collect distinct counts for both sides
  # to determine structural consistency
  local -a left_list=()
  local -a right_list=()
  declare -A left_seen=()
  declare -A right_seen=()

  for (( i=0; i<total; i++ )); do
    IFS="$STRING_SEP" read -r left match right <<< "${titlelist[i]}"
    [[ -z "$match" ]] && right="$left"

    left_list+=("$left")
    right_list+=("$right")

    left_seen["$left"]=1
    right_seen["$right"]=1
  done

  local lc=${#left_seen[@]}
  local rc=${#right_seen[@]}

  # --- Stage 5: Decide dominant side ---
  # Prefer the side with full distinct coverage.
  # If inconclusive, compare Latin letter density.
  local use_side
  if (( lc == total && rc < total )); then
    use_side="left"
  elif (( rc == total && lc < total )); then
    use_side="right"
  else
    local llc rlc score=0
    for (( i=0; i<total; i++ )); do
      llc=$(letter_count "${left_list[i]}" latin)
      rlc=$(letter_count "${right_list[i]}" latin)
      (( llc > rlc )) && (( score++ ))
      (( rlc > llc )) && (( score-- ))
    done
    (( score > 0 )) && use_side="left" || use_side="right"
  fi

  # --- Stage 6: Rebuild output ---
  # Reconstruct tracklist using selected title side
  for (( i=0; i<total; i++ )); do
    IFS="$STRING_SEP" read -r ts _ <<< "${tracklist[i]}"

    [[ "$use_side" == 'left' ]] && title="${left_list[i]}" || title="${right_list[i]}"

    title=$(letter_trim "$title" "0123456789(（)）[【]】")
    printf '%s%s%s\n' "$ts" "$STRING_SEP" "$title"
  done
}

__yt_video_tracklist_repeat_process() {
  local -a tracklist
  readarray -t tracklist
  (( ${#tracklist[@]} > 0 )) || return 0

  # --- last timestamp and title ---
  local last_idx ts title
  last_idx=$(( ${#tracklist[@]} - 1 ))
  IFS="$STRING_SEP" read -r ts title <<< "${tracklist[last_idx]}"

  # --- Step 1: fast keyword detection ---
  local repeat_mode=0 match
  __yt_video_tracklist_repeat_regex_build
  [[ -n "$__YT_VIDEO_TRACKLIST_REPEAT_REGEX" ]] || return 0
  logi "$__YT_VIDEO_TRACKLIST_REPEAT_REGEX"

  local lower_title="${title,,}"
  local duration duration_hms last_sec

  if [[ "$lower_title" =~ $__YT_VIDEO_TRACKLIST_REPEAT_REGEX ]]; then
    # ---- Step 1: keyword detection ----
    repeat_mode=1
    match="${BASH_REMATCH[0]}"
    logi "Repeat: last title '$title' matched '$match'"
 else
    # ---- Step 2: duration fallback ----
    duration=$(yt_video_duration "$1")
    num_is_nonneg_number "$duration" || duration=0
    duration_hms=$(time_s_to_hms "$duration")
    last_sec=$(time_hms_to_s "$ts")

    if (( duration * 2 > last_sec * 3 )); then
      repeat_mode=1
      logi "Repeat: playlist [$ts], duration [$duration_hms], last title '$title'"
    fi
  fi

  # --- Apply result ---
  if (( repeat_mode )); then
    tracklist[last_idx]="${ts}${STRING_SEP}@repeat"
  else
    # detect last track
   local count den avg remain tol lower upper avg_hms remain_hms

    count=${#tracklist[@]}
    den=$(( count - 1 ))
    avg=$(( last_sec / den ))
    remain=$(( duration - last_sec ))

    tol=$__YT_TRACKLIST_END_TOL_PCT
    lower=$(( 100 - tol ))
    upper=$(( 100 + tol ))
    
    if (( remain * 100 >= avg * lower &&
          remain * 100 <= avg * upper )); then
      tracklist+=("$duration_hms${STRING_SEP}@end")
    else
      avg_hms=$(time_s_to_hms "$avg")
      remain_hms=$(time_s_to_hms "$remain")
      logi "Skip last track: remain [$remain_hms], avg [$avg_hms]"
      tracklist[last_idx]="${ts}${STRING_SEP}@end"
    fi
  fi

  printf '%s\n' "${tracklist[@]}"
}

__yt_video_tracklist_repeat_regex_build() {
  local file="$__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE"
  local line
  local -a words=()

  [[ -f "$file" ]] || return 0

  # ---- get mtime (macOS / Linux) ----
  local mtime
  mtime=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null) || return 0

  # ---- no change → skip ----
  [[ "$mtime" == "$__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_MTIME" ]] && return 0

  # ---- rebuild ----
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ "$line" == \#* ]] && continue
    words+=("$line")
  done < "$file"

  if (( ${#words[@]} > 0 )); then
    local IFS='|'
    __YT_VIDEO_TRACKLIST_REPEAT_REGEX="(${words[*]})"
  else
    __YT_VIDEO_TRACKLIST_REPEAT_REGEX=
  fi

  __YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_MTIME="$mtime"
}

# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_video_tracklist() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  # __yt_video_tracklist_repeat_process "$input" < <(
  #   yt_video_tracklist_bilingual_process < <(
  #     __yt_video_tracklist_resolve < <(
  #       yt_video_description "$input"
  #     )
  #   )
  # )
  
  yt_video_tracklist_bilingual_process < <(
    yt_video_tracklist_resolve < <(
      text_demath < <(
        text_filter "$TIME_TIMESTAMP_REGEX" < <(
          yt_video_description "$input"
        )
      )
    )
  )

  return 0
}
