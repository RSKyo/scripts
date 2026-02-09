#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Source-only library: yt.video.tracklist

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
# [[ -n "${__YT_VIDEO_TRACKLIST_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_SOURCED=1

# -------------------------------------------------
# Track title separator patterns
# Domain-specific: used for bilingual track titles
# -------------------------------------------------

readonly __TRACKLIST_SEP_DASH_REGEX='[-–—]'
readonly __TRACKLIST_SEP_PIPE_REGEX='\|'
readonly __TRACKLIST_SEP_SLASH_REGEX='\/'
readonly __TRACKLIST_SEP_DOT_REGEX='·'
readonly __TRACKLIST_SEP_COLON_REGEX='[:：]'

# Round brackets (directional)
readonly __TRACKLIST_SEP_ROUND_L_REGEX='[\(（]'
readonly __TRACKLIST_SEP_ROUND_R_REGEX='[\)）]'

# Square brackets (directional)
readonly __TRACKLIST_SEP_SQUARE_L_REGEX='[\[【]'
readonly __TRACKLIST_SEP_SQUARE_R_REGEX='[\]】]'

# Priority order for separator detection (first match wins)
readonly __TRACKLIST_SEP_CLASSES=(
  DASH
  PIPE
  SLASH
  DOT
  ROUND_L
  ROUND_R
  SQUARE_L
  SQUARE_R
  COLON
)

readonly __TRACKLIST_TIMESTAMP_REGEX='([0-9]{1,2}:[0-9]{2}(:[0-9]{2})?)'
readonly __TRACKLIST_SEP=$'\x1f'

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/description.source.sh"
source "$LIB_DIR/yt/video/duration.source.sh"
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/letter.source.sh"
source "$LIB_DIR/time.source.sh"
source "$LIB_DIR/text.source.sh"
source "$LIB_DIR/num.source.sh"


__yt_video_tracklist_timestamp_side() {
  local sep="$__TRACKLIST_SEP"
  local score=0

  local row left right _

  while IFS= read -r row; do
    IFS="$sep" read -r left _ right <<< "$row"
    (( score += ${#left} - ${#right} ))
  done

  (( score > 0 )) && printf 'right\n' || printf 'left\n'
}

__yt_video_tracklist_repeat_mode() {
  local duration="$1"
  local sep="$__TRACKLIST_SEP"

  local row ts _ last_sec

  while IFS= read -r row; do
    IFS="$sep" read -r _ ts _ <<< "$row"
  done

  last_sec="$(time_parse_hms_to_s "$ts")"
  (( last_sec > 0 )) || return 0

  num_ratio_ge "$duration" "$last_sec" 1.5 && printf 'loop\n'
}

__yt_video_tracklist_raw() {
  local ts_side="$1"   # left | right
  local sep="$__TRACKLIST_SEP"

  local row left ts right

  if [[ "$ts_side" == left ]]; then
    while IFS= read -r row; do
      IFS="$sep" read -r left ts right <<< "$row"
      printf '%s%s%s\n' "$ts" "$sep" "$right"
    done
  else
    while IFS= read -r row; do
      IFS="$sep" read -r left ts right <<< "$row"
      printf '%s%s%s\n' "$ts" "$sep" "$left"
    done
  fi

  return 0
}


__yt_video_tracklist_title_start_min_pos() {
  local rows_name="$1"

  # shellcheck disable=SC2178,SC2034
  local -n rows_ref="$rows_name"

  local sep="$__YT_VIDEO_TRACKLIST_SEP"

  local row ts title pos
  local min_pos=0

  for row in "${rows_ref[@]}"; do
    IFS="$sep" read -r ts title <<< "$row"

    # @loop 行不处理
    [[ "$title" == '@loop' ]] && continue

    pos="$(first_letter_pos "$title")" || continue
    [[ -n "$pos" ]] || continue

    if (( min_pos == 0 || pos < min_pos )); then
      min_pos="$pos"
    fi
  done

  (( min_pos > 0 )) && printf '%s\n' "$min_pos"
  return 0
}

__yt_video_tracklist_trim_title() {
  local rows_name="$1"
  local title_start_min_pos="$2"   # 1-based

  # shellcheck disable=SC2178,SC2034
  local -n rows_ref="$rows_name"

  local sep="$__YT_VIDEO_TRACKLIST_SEP"
  local i ts title

  for (( i=0; i<${#rows_ref[@]}; i++ )); do
    IFS="$sep" read -r ts title <<< "${rows_ref[i]}"

    # @loop 行不处理
    [[ "$title" == '@loop' ]] && continue

    title="$(string_substr "$title" "$title_start_min_pos")"
    title="$(alnum_trim "$title")"

    rows_ref[i]="${ts}${sep}${title}"
  done

  return 0
}







# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_video_tracklist() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  # 1、获取视频描述
  local description
  description="$(yt_video_description "$input")"
  [[ -n "$description" ]] || return 0

  # 2、获取视频总时长
  local duration
  duration="$(yt_video_duration "$input")"
  [[ "$duration" =~ ^[0-9]+$ ]] || return 0

  # 3、过滤出带有时间戳的行，并解析成行结构（left timestamp right）
  local timestamp_parts
  timestamp_parts="$(
    printf '%s\n' "$description" |
    text_filter_parts \
      "$__TRACKLIST_TIMESTAMP_REGEX" \
      --sep "$__TRACKLIST_SEP"
  )"
  [[ -n "$timestamp_parts" ]] || return 0

  
  # 3.1、判断时间戳位置（左/右）
  local timestamp_side
  timestamp_side="$(
    printf '%s\n' "$timestamp_parts" |
    __yt_video_tracklist_timestamp_side
  )"

  # 3.2、判断是否循环播放
  local repeat_mode
  repeat_mode="$(
    printf '%s\n' "$timestamp_parts" |
    __yt_video_tracklist_repeat_mode "$duration"
  )"


  local tracklist_raw
  tracklist_raw="$(
    printf '%s\n' "$timestamp_parts" |
    __yt_video_tracklist_raw "$timestamp_side"
  )"

  

  

  # # 5) 提取原始 tracklist 行（ts + title），并对 loop 行特殊标记
  # __yt_video_tracklist_extract_raw rows "$ts_side" "$is_loop"

  # # 6) 判断标题起始位置（1-based），以便后续切分标题文本和装饰符（如 emoji、括号、引号等）
  # # 注意：这里的标题起始位置是所有 tracklist 行中最靠前的那个，以兼容不同 track 标题装饰不一致的情况
  # # 例如，标题前有序号，1-9是1位符，10及以上是2字符，取最靠前的位置防止截断标题
  # local title_start_min_pos
  # title_start_min_pos="$(__yt_video_tracklist_title_start_min_pos rows)" 
  # [[ -n "$title_start_min_pos" ]] || return 0

  # # 7) 根据标题起始位置切分标题，去除多余文本装饰（保留原始装饰符）
  # __yt_video_tracklist_trim_title rows "$title_start_min_pos"

  # # 2) output rows
  # printf '%s\n' "${rows[@]}"

  return 0
}