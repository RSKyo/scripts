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

readonly __TRACK_SEP_DASH_REGEX='[-–—]'
readonly __TRACK_SEP_PIPE_REGEX='\|'
readonly __TRACK_SEP_SLASH_REGEX='\/'
readonly __TRACK_SEP_DOT_REGEX='·'
readonly __TRACK_SEP_COLON_REGEX='[:：]'

# Round brackets (directional)
readonly __TRACK_SEP_ROUND_L_REGEX='[\(（]'
readonly __TRACK_SEP_ROUND_R_REGEX='[\)）]'

# Square brackets (directional)
readonly __TRACK_SEP_SQUARE_L_REGEX='[\[【]'
readonly __TRACK_SEP_SQUARE_R_REGEX='[\]】]'

# Priority order for separator detection (first match wins)
readonly __TRACK_SEP_CLASSES=(
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

# -------------------------------------------------
# Dependencies
# -------------------------------------------------
# source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../../infra/bootstrap.source.sh"
# 要求 bootstrap 在入口 source，这里只做断言
: "${yt_dlp:?yt_dlp not set (did you source bootstrap?)}"
: "${LIB_DIR:?LIB_DIR not set (did you source bootstrap?)}"

source "$LIB_DIR/yt/video/description.source.sh"
source "$LIB_DIR/yt/video/duration.source.sh"
source "$LIB_DIR/string.source.sh"
source "$LIB_DIR/letter.source.sh"
source "$LIB_DIR/time.source.sh"

readonly __YT_VIDEO_TRACKLIST_TIMESTAMP_REGEX='([0-9]{1,2}:[0-9]{2}(:[0-9]{2})?)'
readonly __YT_VIDEO_TRACKLIST_SEP=$'\x1f'



__yt_video_timestamp_lines() {
  local description="$1"
  [[ -n "$description" ]] || return 0

  while IFS= read -r line; do
    [[ "$line" =~ $__YT_VIDEO_TRACKLIST_TIMESTAMP_REGEX ]] || continue
    printf '%s\n' "$line"
  done <<< "$description"
}

__yt_video_tracklist_rows() {
  local rows_name="$1"
  local -n rows_ref="$rows_name"

  local sep="$__YT_VIDEO_TRACKLIST_SEP"

  while IFS= read -r line; do
    [[ "$line" =~ $__YT_VIDEO_TRACKLIST_TIMESTAMP_REGEX ]] || continue

    local ts="${BASH_REMATCH[1]}"
    local sec
    sec="$(time_parse_hms_to_s "$ts")" || continue

    local left="${line%%"$ts"*}"
    local right="${line#*"$ts"}"

    (( sec == 0 )) && rows_ref=()

    rows_ref+=( "${sec}${sep}${ts}${sep}${left}${sep}${right}" )
  done
}

__yt_video_tracklist_timestamp_side() {
  local rows_name="$1"

  # shellcheck disable=SC2178,SC2034
  local -n rows_ref="$rows_name"

  local sep="$__YT_VIDEO_TRACKLIST_SEP"
  local score=0

  for row in "${rows_ref[@]}"; do
    local sec ts left right
    IFS="$sep" read -r sec ts left right <<< "$row"
    (( score += ${#left} - ${#right} ))
  done

  (( score > 0 )) && printf 'right\n' || printf 'left\n'
}

__yt_video_tracklist_is_loop() {
  local rows_name="$1"
  local duration="$2"

  # shellcheck disable=SC2178,SC2034
  local -n rows_ref="$rows_name"

  local sep="$__YT_VIDEO_TRACKLIST_SEP"
  local last_sec

  # 取最后一条 track 的起始时间
  IFS="$sep" read -r last_sec _ <<< "${rows_ref[-1]}"

  # loop 判定规则（经验值，可调）
  local LOOP_FACTOR_NUM=3     # ≥ 1.5 × last_sec
  local LOOP_FACTOR_DEN=2
  local LOOP_MIN_GAP=120      # ≥ 2 minutes gap

  if (( duration * LOOP_FACTOR_DEN >= last_sec * LOOP_FACTOR_NUM )) &&
     (( duration - last_sec >= LOOP_MIN_GAP )); then
    printf 'loop\n'
  fi
}

__yt_video_tracklist_extract_raw() {
  local rows_name="$1"
  local ts_side="$2"   # left | right
  local is_loop="$3"   # loop | empty

  # shellcheck disable=SC2178,SC2034
  local -n rows_ref="$rows_name"

  local sep="$__YT_VIDEO_TRACKLIST_SEP"
  local i sec ts left right title

  # 行级处理：根据 timestamp_side 选 title，丢弃 sec
  for (( i=0; i<${#rows_ref[@]}; i++ )); do
    IFS="$sep" read -r sec ts left right <<< "${rows_ref[i]}"

    [[ "$ts_side" == left ]] && title="$right" || title="$left"

    rows_ref[i]="${ts}${sep}${title}"
  done

  # 全局处理：loop → 最后一行 title = @loop
  if [[ "$is_loop" == loop ]]; then
    IFS="$sep" read -r ts title <<< "${rows_ref[-1]}"
    rows_ref[-1]="${ts}${sep}@loop"
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

  # shellcheck disable=SC2034
  local -a rows=()

  # 1) 获取时间戳行（纯文本行，未做任何清洗）
  local description
  description="$(yt_video_description "$input")"
  [[ -n "$description" ]] || return 0

  local timestamp_lines
  timestamp_lines="$(__yt_video_timestamp_lines "$description")"
  [[ -n "$timestamp_lines" ]] || return 0

  # 2) 解析时间戳行，构建 tracklist 行结构（sec/ts/left/right），并以最后一个 0 秒为起点过滤
  __yt_video_tracklist_rows rows <<< "$timestamp_lines"
  (( "${#rows[@]}" == 0 )) && return 0

  # 3) 判断时间戳位置（左/右）
  local ts_side
  ts_side="$(__yt_video_tracklist_timestamp_side rows)"

  # 4) 判断是否 loop（末尾 track 起始时间远早于视频总时长）
  local duration
  duration="$(yt_video_duration "$input")"
  [[ "$duration" =~ ^[0-9]+$ ]] || return 0

  local is_loop
  is_loop="$(__yt_video_tracklist_is_loop rows "$duration")"

  # 5) 提取原始 tracklist 行（ts + title），并对 loop 行特殊标记
  __yt_video_tracklist_extract_raw rows "$ts_side" "$is_loop"

  # 6) 判断标题起始位置（1-based），以便后续切分标题文本和装饰符（如 emoji、括号、引号等）
  # 注意：这里的标题起始位置是所有 tracklist 行中最靠前的那个，以兼容不同 track 标题装饰不一致的情况
  # 例如，标题前有序号，1-9是1位符，10及以上是2字符，取最靠前的位置防止截断标题
  local title_start_min_pos
  title_start_min_pos="$(__yt_video_tracklist_title_start_min_pos rows)" 
  [[ -n "$title_start_min_pos" ]] || return 0

  # 7) 根据标题起始位置切分标题，去除多余文本装饰（保留原始装饰符）
  __yt_video_tracklist_trim_title rows "$title_start_min_pos"

  # 2) output rows
  printf '%s\n' "${rows[@]}"

  return 0
}