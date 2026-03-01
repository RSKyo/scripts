#!/usr/bin/env bash
# Source-only library: lib/yt/video/tracklist.end
# shellcheck disable=SC1091

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__YT_VIDEO_TRACKLIST_END_SOURCED+x}" ]] && return 0
__YT_VIDEO_TRACKLIST_END_SOURCED=1

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/yt/video/duration.source.sh"
source "$LIB_DIR/num.source.sh"
source "$LIB_DIR/time.source.sh"
readonly __YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE="$LIB_DIR/yt/video/repeat_keywords.txt"

readonly __YT_VIDEO_TRACKLIST_REPEAT_RATIO=1.5
readonly __YT_VIDEO_TRACKLIST_END_TOL_PCT=30
__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_REGEX=
__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_FILE_MTIME=

# Build repeat keyword regex from file.
# Cache by file mtime to avoid unnecessary rebuild.
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

# Post-process tracklist
# Input : <sec><sep><ts><sep><title>
# Output: processed tracklist
yt_video_tracklist_end_process() {
  local url="${1:?yt_video_tracklist_end_process: missing url}"

  yt_video_tracklist_build_repeat_keywords_regex

  # --- Load tracklist ---
  local -a tracklist
  readarray -t tracklist
  total=${#tracklist[@]}

  (( total == 0 )) && return 0

  # --- Inspect last track ---
  local last_idx sec ts title
  last_idx=$(( total - 1 ))
  IFS="$STRING_SEP" read -r sec ts title <<< "${tracklist[last_idx]}"

  # --- Repeat (keyword) ---
  if [[ "${title,,}" =~ $__YT_VIDEO_TRACKLIST_REPEAT_KEYWORDS_REGEX ]]; then
    logi "Repeat detected (keyword): [$ts] '$title'"
    tracklist[last_idx]="${sec}${STRING_SEP}${ts}${STRING_SEP}@repeat"
    printf '%s\n' "${tracklist[@]}"
    return 0
  fi

  # --- Video duration ---
  local video_sec video_ts sec_ratio

  video_sec=$(yt_video_duration "$url")
  video_sec=$(num_fixed "$video_sec" 0)
  video_ts=$(time_s_to_hms "$video_sec")

  # --- Validate timestamps ---
  for (( i=0; i<total; i++ )); do
    IFS="$STRING_SEP" read -r sec ts title <<< "${tracklist[i]}"
    if (( sec < video_sec )); then
      last_idx="$i"
    else
      logi "Track [$ts] '$title' exceeds video duration [$video_ts] — truncated automatically."
    fi
  done

  total=$(( last_idx + 1 ))
  IFS="$STRING_SEP" read -r sec ts title <<< "${tracklist[last_idx]}"
  
  # --- Repeat (ratio) ---
  sec_ratio=$(num_quotient "$video_sec" "$sec") || 
    sec_ratio="$__YT_VIDEO_TRACKLIST_REPEAT_RATIO"

  if num_cmp "$sec_ratio" ge "$__YT_VIDEO_TRACKLIST_REPEAT_RATIO"; then
    logi "Repeat detected (ratio ${sec_ratio}): [$ts] '$title'"
    tracklist[last_idx]="${sec}${STRING_SEP}${ts}${STRING_SEP}@repeat"
    
    for (( i=0; i<=last_idx; i++ )); do
      printf '%s\n' "${tracklist[i]}"
    done

    return 0
  fi

  # --- Natural end detection ---

  local den avg remain
  local tol lower upper
  local video_end_line
  local avg_hms remain_hms

  den=$(( total - 1 ))
  avg=$(( sec / den ))
  remain=$(( video_sec - sec ))

  tol="$__YT_VIDEO_TRACKLIST_END_TOL_PCT"
  lower=$(( 100 - tol ))
  upper=$(( 100 + tol ))
  
  if (( remain * 100 >= avg * lower &&
        remain * 100 <= avg * upper )); then
    video_end_line="${video_sec}${STRING_SEP}${video_ts}${STRING_SEP}@end"
  else
    avg_hms=$(time_s_to_hms "$avg")
    remain_hms=$(time_s_to_hms "$remain")
    logi "Skip last track: $title [$remain_hms], avg [$avg_hms]"
    tracklist[last_idx]="${sec}${STRING_SEP}${ts}${STRING_SEP}@end"
  fi
  
  # --- Output ---
  for (( i=0; i<=last_idx; i++ )); do
    printf '%s\n' "${tracklist[i]}"
  done

  if [[ -n "$video_end_line" ]]; then
    printf '%s\n' "$video_end_line"
  fi

}

yt_video_tracklist_build_repeat_keywords_regex