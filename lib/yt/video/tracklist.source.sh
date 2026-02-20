#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.video.tracklist

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
# [[ -n "${__YT_VIDEO_TRACKLIST_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_SOURCED=1

# Separator regex priority list (first match wins)
readonly __TRACKLIST_TITLE_SEP_REGEXES=(
  '[-–—]'
  '\|'
  '\/'
  '·'
  '[\(（]'
  '[\)）]'
  '[\[【]'
  '[\]】]'
)

readonly __TRACKLIST_SEP=$'\x1f'
readonly __TRACKLIST_MAX_POS=9999

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/description.source.sh"
source "$LIB_DIR/yt/video/duration.source.sh"
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/letter.source.sh"
source "$LIB_DIR/time.source.sh"
source "$LIB_DIR/text.source.sh"
source "$LIB_DIR/num.source.sh"

__yt_video_tracklist_resolve() {
  local -a lines=()
  text_to_array lines

  # --- detect structure start (00:00) ---
  declare -A ts_map=()
  local zero_idx=''
  local i=0
  local ts=-1
  local prev_ts=-1
  local match=''

  for line in "${lines[@]}"; do
    
    if _time_match match "$line"; then
      match="${match//[[:space:]]/}"
      _time_hms_to_s ts "$match"

      if (( ts == 0 )); then
        zero_idx="$i"
        prev_ts=0
      elif [[ -n "$zero_idx" && $ts -gt $prev_ts ]]; then
        prev_ts="$ts"
      else
        zero_idx=''
        prev_ts=-1
      fi

      if [[ -n "$zero_idx" ]]; then
        ts_map["$zero_idx"]="$zero_idx,$i,$ts,$line"
      fi
    fi

    ((i++))
  done

  local key sel_key=''
  local max_ts=-1
  local start_idx end_idx end_ts end_line

  for key in "${!ts_map[@]}"; do
    IFS=',' read -r start_idx end_idx end_ts end_line <<< "${ts_map[$key]}"

    if (( end_ts > max_ts )); then
      max_ts="$end_ts"
      sel_key="$key"
    fi
  done

  [[ -n "$sel_key" ]] || return 0

  IFS=',' read -r start_idx end_idx end_ts end_line <<< "${ts_map[$sel_key]}"

  local tracklist_lines=()

  if (( start_idx >= 0 && end_idx >= start_idx )); then
    local length=$(( end_idx - start_idx + 1 ))
    tracklist_lines=("${lines[@]:$start_idx:$length}")
  fi

  # --- detect timestamp side ---
  local line match left right
  local score=0

  for line in "${ltracklist_lines[@]}"; do
    _time_match match "$line" || continue
    left="${line%%"$match"*}"
    right="${line#*"$match"}"

    (( score += ${#left} - ${#right} ))
  done

  # --- normalize and build tracklist ---
  local -a tracklist=()

  for line in "${tracklist_lines[@]}"; do
    _time_match match "$line" || continue
    left="${line%%"$match"*}"
    right="${line#*"$match"}"
    match="${match//[[:space:]]/}"

    if (( score > 0 )); then
      tracklist+=("$match$__TRACKLIST_SEP$left")
    else
      tracklist+=("$match$__TRACKLIST_SEP$right")
    fi
  done

  # --- detect minimal title start ---
  local max_pos="$__TRACKLIST_MAX_POS"
  local min_pos="$max_pos"
  local ts title pos 

  for line in "${tracklist[@]}"; do
    IFS="$__TRACKLIST_SEP" read -r ts title <<< "$line"
    pos="$(first_letter_pos "$title")" || continue
    [[ -n "$pos" ]] || continue
    (( pos < min_pos )) && min_pos="$pos"
  done

  (( min_pos < max_pos )) || min_pos=1

  # --- output trimmed tracklist ---
  local title_trimmed

  for line in "${tracklist[@]}"; do
    IFS="$__TRACKLIST_SEP" read -r ts title <<< "$line"
    _string_slice title_trimmed "$title" "$min_pos"
    title_trimmed="$(alnum_trim "$title_trimmed")"

    printf '%s%s%s\n' "$ts" "$__TRACKLIST_SEP" "$title_trimmed"
  done
}

__yt_video_tracklist_bilingual_process() {
  local -a tracklist=()
  text_to_array tracklist

  local -a ts_list=()
  local -a title_list=()
  local line ts title len

  len=${#tracklist[@]}

  for line in "${tracklist[@]}"; do
    IFS="$__TRACKLIST_SEP" read -r ts title <<< "$line"
    ts_list+=("$ts")
    title_list+=("$title")
  done

  local regex sep_regex

  for regex in "${__TRACKLIST_TITLE_SEP_REGEXES[@]}"; do
    
    printf '%s\n' "${title_list[@]}" | 
    text_supports "$regex" 0.15 0.85 0.6 || continue
    sep_regex="$regex"
    break
  done

  [[ -n "$sep_regex" ]] || { printf '%s\n' "${tracklist[@]}" ; return 0; }

  local -a title_expand=()
  local left match right
  local -a left_list=()
  local -a right_list=()

  _text_expand title_expand "$sep_regex" 0.15 0.85 <<< \
    "$(printf '%s\n' "${title_list[@]}")"

  for line in "${title_expand[@]}"; do
    IFS="$__TRACKLIST_SEP" read -r left match right <<< "$line"
    [[ -n "$match" ]] || { right="$left"; }
    left_list+=("$left")
    right_list+=("$right")
  done

  # 判断哪一侧更可能是标题主体，原则如下：
  # - 如果一侧无重复，另一侧有重复，则无重复的一侧更可能是标题主体，因为专辑、艺术家等信息更可能重复出现。
  # - 否则，优先拉丁字母较多的一侧更可能是标题主体
  local lt lc rt rc use_side i

  lc=$(array_unique_count left_list)
  lt=${#left_list[@]}
  rc=$(array_unique_count right_list)
  rt=${#right_list[@]}

  if (( lc == lt && rc < rt )); then
    use_side="left"
  elif (( rc == rt && lc < lt )); then
    use_side="right"
  else
    local score=0
    local llc rlc diff

    for (( i=0; i<len; i++ )); do
      llc="$(letter_script_count "${left_list[i]}" latin)"
      rlc="$(letter_script_count "${right_list[i]}" latin)"
      _num_diff diff "$llc" "$rlc" 0
      _num_sum score "$score" "$diff" 0
    done

    logd 'lib' "title Latin score: $score"

    if num_cmp "$score" ge 0; then
      use_side="left"
    else
      use_side="right"
    fi
  fi

  for (( i=0; i<len; i++ )); do
    if [[ "$use_side" == 'left' ]]; then
      printf '%s%s%s\n' "${ts_list[i]}" "$__TRACKLIST_SEP" "${left_list[i]}"
    else
      printf '%s%s%s\n' "${ts_list[i]}" "$__TRACKLIST_SEP" "${right_list[i]}"
    fi
  done
}


# -------------------------------------------------
# repeat
# -------------------------------------------------



# __yt_video_tracklist_repeat_mode() {
#   local duration="$1"
#   local ts=
#   local last_sec

#   # 取最后一个时间戳
#   while IFS= read -r ts; do
#     :
#   done

#   [[ -n "$ts" ]] || return 0

#   last_sec="$(time_parse_hms_to_s "$ts")"
#   (( last_sec > 0 )) || return 0

#   num_ratio_ge "$duration" "$last_sec" 1.5 && printf 'repeat\n'
#   return 0
# }



# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_video_tracklist() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  yt_video_description "$input" |
  text_filter "$__TIME_TIMESTAMP_REGEX" |
  __yt_video_tracklist_resolve |
  __yt_video_tracklist_bilingual_process



  return 0
}