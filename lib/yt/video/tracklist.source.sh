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

# -------------------------------------------------
# Internal functions
# -------------------------------------------------
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

__yt_video_tracklist_repeat_mode() {
  local duration="$1"
  local sep="$__TRACKLIST_SEP"

  local row ts _ last_sec

  while IFS= read -r row; do
    IFS="$sep" read -r ts _ <<< "$row"
  done

  last_sec="$(time_parse_hms_to_s "$ts")"
  (( last_sec > 0 )) || return 0

  num_ratio_ge "$duration" "$last_sec" 1.5 && printf 'repeat\n'
}

__yt_video_tracklist_start_min_pos() {
  local sep="$__TRACKLIST_SEP"

  local row ts title pos
  local min_pos=0

  while IFS= read -r row; do
    IFS="$sep" read -r ts title <<< "$row"

    pos="$(first_letter_pos "$title")" || continue
    [[ -n "$pos" ]] || continue

  (( pos < min_pos )) && min_pos="$pos"
 
  done

  (( min_pos > 0 )) && printf '%s\n' "$min_pos"
  return 0
}

__yt_video_tracklist_title_trim() {
  local min_pos="$1"   # 1-based
  local sep="$__TRACKLIST_SEP"

  local row ts title

  while IFS= read -r row; do
    IFS="$sep" read -r ts title <<< "$row"

    title="$(string_substr "$title" "$min_pos")"
    title="$(alnum_trim "$title")"

    printf '%s%s%s\n' "$ts" "$sep" "$title"
  done

  return 0
}









# -------------------------------------------------
# Public API
# -------------------------------------------------
yt_video_tracklist() {
  local input="$1"
  [[ -n "$input" ]] || return 0

  # 1、获取视频描述文本
  local description
  description="$(yt_video_description "$input")"
  [[ -n "$description" ]] || return 0

  # 2、从描述文本中提取出可能的 tracklist 行
  local expanded_lines
  expanded_lines="$(
    printf '%s\n' "$description" |
    text_match_expand \
      "$__TRACKLIST_TIMESTAMP_REGEX" \
      --sep "$__TRACKLIST_SEP"
  )"
  [[ -n "$expanded_lines" ]] || return 0
  
  # 3、判断时间戳在 track title 的左侧还是右侧
  local timestamp_side
  timestamp_side="$(
    printf '%s\n' "$expanded_lines" |
    __yt_video_tracklist_timestamp_side
  )"

  # 4、根据时间戳位置提取出原始 tracklist（包含时间戳和标题，但未处理标题前的空格等杂项）
  local tracklist_raw
  tracklist_raw="$(
    printf '%s\n' "$expanded_lines" |
    __yt_video_tracklist_raw "$timestamp_side"
  )"

  # 5、获取 track title 的起始位置最小值（用于后续批量修剪标题前的杂项）
  local min_pos
  min_pos="$(
    printf '%s\n' "$tracklist_raw" |
    __yt_video_tracklist_start_min_pos
  )"

  # 6、修剪 track title 前的杂项（如空格、特殊符号等），得到 trimmed 的 tracklist
  local tracklist_trimmed
  tracklist_trimmed="$(
    printf '%s\n' "$tracklist_raw" |
    __yt_video_tracklist_title_trim "$min_pos"
  )"



  # 7、（可选）判断是否存在重复播放模式（即最后一个 track 的时间戳与视频总时长的比例是否超过某个阈值）
  local duration
  duration="$(yt_video_duration "$input")"
  [[ "$duration" =~ ^[0-9]+$ ]] || return 0
  
  # 注意：如果无法获取视频总时长，则无法判断是否存在重复播放模式，此时默认不启用重复播放模式
  local repeat_mode
  repeat_mode="$(
    printf '%s\n' "$tracklist_raw" |
    __yt_video_tracklist_repeat_mode "$duration"
  )"


  printf '%s\n' "$tracklist_trimmed"

  return 0
}