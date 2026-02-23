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
source "$LIB_DIR/array.source.sh"
source "$LIB_DIR/time.source.sh"

readonly __YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE="$LIB_DIR/yt/video/repeat_keywords.txt"

__yt_video_tracklist_resolve() {
  local -a lines
  readarray -t lines < <(text_filter_expand "$TIME_TIMESTAMP_REGEX")
  (( ${#lines[@]} > 0 )) || return 0

  local i line _
  local left match right

  # --- Detect tracklist lines (00:00 -> Maximum) ---
  # Select lines from the segment starting at 00:00 with the largest end timestamp.
  local -a tracklist_lines
  local start_idx=-1 end_idx=-1
  local zero_idx=-1 max_sec=-1

  for (( i=0; i<${#lines[@]}; i++ )); do
    line="${lines[i]}"
    IFS="$STRING_SEP" read -r _ match _ <<< "$line"
    match="${match//[[:space:]]/}"
    sec=$(time_hms_to_s "$match")

    (( sec == 0 )) && zero_idx="$i"
    if (( sec > max_sec )) && (( zero_idx >= 0 )); then
      start_idx="$zero_idx"
      end_idx="$i"
      max_sec="$sec"
    fi
  done

  (( start_idx >=0 )) || return 0
  tracklist_lines=("${lines[@]:start_idx:$(( end_idx - start_idx + 1 ))}")

  for (( i=0; i<${#tracklist_lines[@]}; i++ )); do
    line="${tracklist_lines[i]}"
    IFS="$STRING_SEP" read -r left match right <<< "$line"
    left=$(letter_demath "$left")
    right=$(letter_demath "$right")

    tracklist_lines[i]="${left}${STRING_SEP}${match}${STRING_SEP}${right}"
  done

  # --- Detect timestamp side ---
  local score=0

  for line in "${tracklist_lines[@]}"; do
    IFS="$STRING_SEP" read -r left _ right <<< "$line"

    (( ${#left} > ${#right} )) && (( score++ ))
    (( ${#right} > ${#left} )) && (( score-- ))
  done

  # --- Normalize and build tracklist ---
  local -a tracklist
  local ts title

  for line in "${tracklist_lines[@]}"; do
    IFS="$STRING_SEP" read -r left match right <<< "$line"
    
    if (( score > 0 )); then
      tracklist+=("$match$STRING_SEP$left")
    else
      tracklist+=("$match$STRING_SEP$right")
    fi
  done

  # --- Detect minimal title start ---
  local max_pos=9999
  local min_pos="$max_pos"
  local pos 

  for line in "${tracklist[@]}"; do
    IFS="$STRING_SEP" read -r ts title <<< "$line"

    pos="$(first_letter_pos "$title")" || continue
    (( pos > 0 && pos < min_pos )) && min_pos="$pos"
  done

  (( min_pos < max_pos )) || min_pos=1

  # --- output trimmed tracklist ---
  for line in "${tracklist[@]}"; do
    IFS="$STRING_SEP" read -r ts title <<< "$line"

    ts="${ts//[[:space:]]/}"
    title=$(string_slice "$title" "$min_pos")
    title=$(letter_trim "$title" "0-9\(（\)）\[【\]】")
    printf '%s%s%s\n' "$ts" "$STRING_SEP" "$title"
  done
}

__yt_video_tracklist_bilingual_process() {
  local -a tracklist
  readarray -t tracklist
  (( ${#tracklist[@]} > 0 )) || return 0

  local -a ts_list=()
  local -a title_list=()
  local line ts title len

  len=${#tracklist[@]}

  for line in "${tracklist[@]}"; do
    IFS="$STRING_SEP" read -r ts title <<< "$line"
    ts_list+=("$ts")
    title_list+=("$title")
  done

  local regex sep_regex

  for regex in "${__YT_VIDEO_TRACKLIST_TITLE_SEP_REGEXES[@]}"; do
    text_supports "$regex" 0 1 0.6 < <(
      printf '%s\n' "${title_list[@]}"
    ) || continue
    sep_regex="$regex"
    break
  done

  [[ -n "$sep_regex" ]] || { printf '%s\n' "${tracklist[@]}" ; return 0; }

  local -a title_expanded
  local left match right
  local -a left_list
  local -a right_list

  readarray -t title_expanded < <(
    text_expand "$sep_regex" 0 1 < <(
      printf '%s\n' "${title_list[@]}"
    )
  )
  
  for line in "${title_expanded[@]}"; do
    IFS="$STRING_SEP" read -r left match right <<< "$line"
    [[ -n "$match" ]] || { right="$left"; }
    left_list+=("$left")
    right_list+=("$right")
  done

  # 判断哪一侧更可能是标题主体，原则如下：
  # - 如果一侧无重复，另一侧有重复，则无重复的一侧更可能是标题主体，因为专辑、艺术家等信息更可能重复出现。
  # - 否则，优先拉丁字母较多的一侧更可能是标题主体
  local lt lc rt rc use_side

  lc=$(array_distinct_count left_list)
  lt=${#left_list[@]}
  rc=$(array_distinct_count right_list)
  rt=${#right_list[@]}

  if (( lc == lt && rc < rt )); then
    use_side="left"
  elif (( rc == rt && lc < lt )); then
    use_side="right"
  else
    local score=0
    local llc rlc

    for (( i=0; i<len; i++ )); do
      llc="$(letter_script_count "${left_list[i]}" latin)"
      rlc="$(letter_script_count "${right_list[i]}" latin)"
      (( llc > rlc )) && (( score++ ))
      (( rlc > llc )) && (( score-- ))
    done

    if (( score > 0 )); then
      use_side="left"
    else
      use_side="right"
    fi
  fi

  for (( i=0; i<len; i++ )); do
    if [[ "$use_side" == 'left' ]]; then
      title="${left_list[i]}"
    else
      title="${right_list[i]}"
    fi
    title=$(letter_trim "$title" "0-9\(（\)）\[【\]】")
    printf '%s%s%s\n' "${ts_list[i]}" "$STRING_SEP" "$title"
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

  __yt_video_tracklist_repeat_process "$input" < <(
    __yt_video_tracklist_bilingual_process < <(
      __yt_video_tracklist_resolve < <(
        yt_video_description "$input"
      )
    )
  )

  return 0
}
