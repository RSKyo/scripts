#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.end

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
# [[ -n "${__YT_VIDEO_TRACKLIST_REPEAT_SOURCED+x}" ]] && return 0
# __YT_VIDEO_TRACKLIST_REPEAT_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/num.source.sh"
source "$LIB_DIR/time.source.sh"
readonly __YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE="$LIB_DIR/yt/video/repeat_keywords.txt"

readonly __YT_VIDEO_TRACKLIST_REPEAT_RATIO=1.5
readonly __YT_VIDEO_TRACKLIST_END_TOL_PCT=30
__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_REGEX=
__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE_MTIME=

yt_video_tracklist_build_repeat_keywords_regex() {
  local file="$__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE"
  [[ -f "$file" ]] || return 0

  # ---- get mtime (macOS / Linux) ----
  local mtime
  mtime=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null) || return 0
  [[ "$mtime" == "$__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE_MTIME" ]] && return 0
  __YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE_MTIME="$mtime"

  # ---- rebuild ----
  local line
  local -a words=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue
    words+=("$line")
  done < "$file"

  if (( ${#words[@]} > 0 )); then
    local IFS='|'
    __YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_REGEX="(${words[*]})"
  else
    __YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_REGEX=
  fi
}



yt_video_tracklist_end_process() {
  local url="$1"
  if [[ -z "$url" ]]; then
    loge 'missing url'
    return 2
  fi

  local -a tracklist
  readarray -t tracklist

  local total
  total=${#tracklist[@]}
  (( total > 0 )) || return 0

  # --- last timestamp and title ---
  local last_idx ts title
  last_idx=$(( total - 1 ))
  IFS="$STRING_SEP" read -r ts title <<< "${tracklist[last_idx]}"

  # --- Step 1: fast keyword detection ---
  local repeat_mode=0

  yt_video_tracklist_build_repeat_keywords_regex
  logi "$__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_REGEX"

  local lower_title="${title,,}"
  local video_sec video_hms last_sec sec_ratio

  if [[ "$lower_title" =~ $__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_REGEX ]]; then
    # ---- Step 1: keyword detection ----
    repeat_mode=1
    logi "Repeat: last title '$title'"
  else
    # ---- Step 2: duration fallback ----
    video_sec=$(yt_video_duration "$url")
    video_sec=$(num_fixed "$video_sec" 0)
    video_hms=$(time_s_to_hms "$video_sec")
    last_sec=$(time_hms_to_s "$ts")
    sec_ratio=$(num_quotient "$video_sec" "$last_sec") || sec_ratio=__YT_VIDEO_TRACKLIST_REPEAT_RATIO

    if num_cmp "$sec_ratio" ge "$__YT_VIDEO_TRACKLIST_REPEAT_RATIO"; then
      repeat_mode=1
      logi "Repeat: [$ts]/[$video_hms], last title '$title'"
    fi
  fi

  # --- Apply result ---
  if (( repeat_mode )); then
    tracklist[last_idx]="${ts}${STRING_SEP}@repeat"
  else
    # detect last track
   local den avg remain tol lower upper avg_hms remain_hms

    den=$(( total - 1 ))
    avg=$(( last_sec / den ))
    remain=$(( video_sec - last_sec ))

    tol="$__YT_VIDEO_TRACKLIST_END_TOL_PCT"
    lower=$(( 100 - tol ))
    upper=$(( 100 + tol ))
    
    if (( remain * 100 >= avg * lower &&
          remain * 100 <= avg * upper )); then
      tracklist+=("$video_hms${STRING_SEP}@end")
    else
      tracklist[last_idx]="${ts}${STRING_SEP}@end"
      avg_hms=$(time_s_to_hms "$avg")
      remain_hms=$(time_s_to_hms "$remain")
      logi "Skip last track: remain [$remain_hms], avg [$avg_hms]"
    fi
  fi

  printf '%s\n' "${tracklist[@]}"
}

yt_video_tracklist_build_repeat_keywords_regex