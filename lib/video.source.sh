#!/usr/bin/env bash
# Source-only library: lib/video
# shellcheck disable=SC1091,2154

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
# [[ -n "${__VIDEO_SOURCED+x}" ]] && return 0
# __VIDEO_SOURCED=1

# --- Dependencies ------------------------------------------------------------

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/num.source.sh"
source "$LIB_DIR/file.source.sh"

readonly __YT_VIDEO_SMARTCUT_MARGIN=15

video_keyframes() {
    local file="$1"

    "$ffprobe" \
    -v error \
    -select_streams v:0 \
    -skip_frame nokey \
    -show_entries frame=best_effort_timestamp_time \
    -of default=noprint_wrappers=1:nokey=1 \
    "$file"
}

video_keyframe_after() {
  local file="$1"
  local sec="$2"
  local margin="$__YT_VIDEO_SMARTCUT_MARGIN"

  "$ffprobe" -v error \
    -select_streams v:0 \
    -skip_frame nokey \
    -show_entries frame=best_effort_timestamp_time \
    -read_intervals "$((sec-1))%+$((margin+1))" \
    -of default=noprint_wrappers=1:nokey=1 \
    "$file" |
  awk -v s="$sec" '$1+0 >= s { print; exit }'

  return 0
}

video_keyframe_before() {
  local file="$1"
  local sec="$2"
  local margin="$__YT_VIDEO_SMARTCUT_MARGIN"

  "$ffprobe" -v error \
    -select_streams v:0 \
    -skip_frame nokey \
    -show_entries frame=best_effort_timestamp_time \
    -read_intervals "$((sec-margin))%+${margin}" \
    -of default=noprint_wrappers=1:nokey=1 \
    "$file" |
  tail -n1

  return 0
}

video_cut() {
  local file="${1:?video_cut: missing file}"
  local start="${2:?video_cut: missing start}"
  local end="${3:?video_cut: missing end}"
  local out="${4:-"$file"}"

  local kf_after_start
  local kf_before_end
  kf_after_start="$(video_keyframe_after "$file" "$start")" || return 1
  kf_before_end="$(video_keyframe_before "$file" "$end")" || return 1

  local tmpdir head mid tail cut
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  head="$tmpdir/head.mp4"
  mid="$tmpdir/mid.mp4"
  tail="$tmpdir/tail.mp4"
  cut="$tmpdir/cut.mp4"

  if num_cmp "$start" ne "$kf_after_start"; then
    "$ffmpeg" -v error -ss "$start" -to "$kf_after_start" -i "$file" \
      -c:v libx264 -c:a copy "$head"
  fi

  if num_cmp "$kf_after_start" ne "$kf_before_end"; then
    "$ffmpeg" -v error -ss "$kf_after_start" -to "$kf_before_end" -i "$file" \
      -c copy "$mid" || return 1
  fi

  if num_cmp "$kf_before_end" ne "$end"; then
    "$ffmpeg" -v error -ss "$kf_before_end" -to "$end" -i "$file" \
      -c:v libx264 -c:a copy "$tail"
  fi

  "$ffmpeg" -v error \
  -f concat -safe 0 \
  -i <(
    [[ -s "$head" ]] && printf "file '%s'\n" "$head"
    [[ -s "$mid"  ]] && printf "file '%s'\n" "$mid"
    [[ -s "$tail" ]] && printf "file '%s'\n" "$tail"
  ) \
  -c copy "$cut" || return 1

  mv -f "$cut" "$out"

  return 0
}

video_metadata_write() {
  local file="${1:?video_metadata_write: missing file}"
  shift

  local key value
  local -a pairs=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --*=*)
        key="${1%%=*}"
        key="${key#--}"
        value="${1#*=}"
        pairs+=("$key=$value")
        ;;
      *)
        loge "invalid option: $1"
        return 2
        ;;
    esac
    shift
  done

  (( ${#pairs[@]} > 0 )) || return 0

  local comment
  comment="$(IFS=';'; printf '%s' "${pairs[*]}")"

  local dir ext tmpfile
  dir="$(dirname "$file")"
  ext="${file##*.}"

  tmpfile="$(file_tmp "$dir" "$ext")" || return 1
  trap 'rm -f -- "$tmpfile"' RETURN

  "$ffmpeg" -y -v error \
    -i "$file" \
    -map_metadata 0 \
    -c copy \
    -metadata "comment=$comment" \
    "$tmpfile" || return 1

  mv -- "$tmpfile" "$file" || return 1
}

video_metadata_read() {
  local file="${1:?video_metadata_read: missing file}"
  local key="${2:?video_metadata_read: missing key}"

  local comment pair k v

  comment="$("$ffprobe" -v error \
    -show_entries format_tags=comment \
    -of default=noprint_wrappers=1:nokey=1 \
    -i "$file")"

  [[ -n "$comment" ]] || return 0

  IFS=';' read -ra pairs <<< "$comment"

  for pair in "${pairs[@]}"; do
    k="${pair%%=*}"
    v="${pair#*=}"
    [[ "$k" == "$key" ]] && {
      printf '%s\n' "$v"
      return 0
    }
  done
}