#!/usr/bin/env bash
# time.source.sh
# Time utilities module.ing,

# shellcheck disable=SC1091,SC2034

# Prevent multiple sourcing
[[ -n "${__TIME_SOURCED+x}" ]] && return 0
__TIME_SOURCED=1

# Match mm:ss or hh:mm:ss (optional spaces around ':')
readonly __TIME_TIMESTAMP_REGEX='[0-9]+[[:space:]]*:[[:space:]]*[0-5][0-9]([[:space:]]*:[[:space:]]*[0-5][0-9])?'

# Time unit scales (base: milliseconds)
readonly __TIME_SCALE_ms=1
readonly __TIME_SCALE_s=1000
readonly __TIME_SCALE_m=$((60*1000))
readonly __TIME_SCALE_h=$((3600*1000))

# Expose internal separator as public constant (read-only).
readonly TIME_TIMESTAMP_REGEX="$__TIME_TIMESTAMP_REGEX"

# time_normalize <time_string>
# Remove all whitespace from time string.
# Example: "01 : 02 : 03" -> "01:02:03"
time_normalize() {
  local time_string="$1"
  printf '%s\n' "${time_string//[[:space:]]/}"
}

# time_s_to_hms <seconds> [hour_width]
# Format seconds as mm:ss or h:mm:ss.
time_s_to_hms() {
  local time_seconds="${1:-0}"
  local hour_width="${2:-0}"

  local hours=$(( time_seconds / 3600 ))
  local minutes=$(( (time_seconds % 3600) / 60 ))
  local seconds=$(( time_seconds % 60 ))

  if (( hour_width > 0 )); then
    printf "%0*d:%02d:%02d\n" "$hour_width" "$hours" "$minutes" "$seconds"
  elif (( hours > 0 )); then
    printf "%d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
  else
    printf "%02d:%02d\n" "$minutes" "$seconds"
  fi
}

# time_hms_to_s <hms>
# Convert mm:ss or hh:mm:ss to seconds.
time_hms_to_s() {
  local time_string="$1"

  local -a segments=() 
  IFS=':' read -r -a segments <<< "$time_string"
  local segment_count="${#segments[@]}"

  if (( segment_count == 3 )); then
    local hours="${segments[0]}"
    local minutes="${segments[1]}"
    local seconds="${segments[2]}"

    printf '%s\n' $(( 10#$hours * 3600 + 10#$minutes * 60 + 10#$seconds ))
  elif (( segment_count == 2 )); then
    local minutes="${segments[0]}"
    local seconds="${segments[1]}"

    printf '%s\n' $(( 10#$minutes * 60 + 10#$seconds ))
  else
    printf '%s\n' 0
  fi
}

# time_convert <value> <from_unit> <to_unit>
# Convert between ms, s, m, h.
time_convert() {
  local time_value="$1"
  local from_unit="$2"
  local to_unit="$3"

  local from_scale_var="__TIME_SCALE_${from_unit}"
  local to_scale_var="__TIME_SCALE_${to_unit}"

  local from_scale="${!from_scale_var}"
  local to_scale="${!to_scale_var}"

  printf '%s\n' $(( time_value * from_scale / to_scale ))
}
