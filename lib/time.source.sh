#!/usr/bin/env bash
# time.source.sh
# Time utilities for matching, parsing, formatting,
# and unit conversion between ms, s, m, h.
#
# Design philosophy:
# - Contract-based: assumes valid input where specified.
# - Matching functions return 1 on failure.
# - Conversion/formatting functions always return 0.
# - No defensive validation unless explicitly stated.

# Prevent multiple sourcing
[[ -n "${__TIME_SOURCED+x}" ]] && return 0
__TIME_SOURCED=1

# Match mm:ss or hh:mm:ss
readonly __TIME_TIMESTAMP_REGEX='[0-9]+[[:space:]]*:[[:space:]]*[0-5][0-9]([[:space:]]*:[[:space:]]*[0-5][0-9])?'

# Time unit scales (base: milliseconds)
readonly __TIME_SCALE_ms=1
readonly __TIME_SCALE_s=1000
readonly __TIME_SCALE_m=$((60*1000))
readonly __TIME_SCALE_h=$((3600*1000))

# _time_match <out_ref> <text>
# Extract the first timestamp (mm:ss or hh:mm:ss) from <text>.
# Returns 0 if matched, 1 otherwise.
_time_match() {
  local -n out_ref="$1"
  local text="$2"

  [[ "$text" =~ $__TIME_TIMESTAMP_REGEX ]] || return 1
  out_ref="${BASH_REMATCH[0]}"
}

# time_match <text>
# Print the first matched timestamp.
# Returns 0 if matched, 1 otherwise.
time_match() {
  local result
  _time_match result "$@" || return 1
  printf '%s\n' "$result"
}

# _time_s_to_hms <out_ref> <seconds> [hour_width]
# Convert seconds to a formatted time string.
# - If hour_width > 0, always output h:mm:ss with minimum hour padding.
# - Otherwise, output h:mm:ss when hour > 0, or mm:ss if hour == 0.
# Assumes <seconds> is a valid integer.
# Always returns 0.
_time_s_to_hms() {
  local -n out_ref="$1"
  local s="${2:-0}"
  local hw="${3:-0}"

  local h=$(( s / 3600 ))
  local m=$(( (s % 3600) / 60 ))
  local r=$(( s % 60 ))

  if (( hw > 0 )); then
    printf -v out_ref "%0*d:%02d:%02d" "$hw" "$h" "$m" "$r"
  elif (( h > 0 )); then
    printf -v out_ref "%d:%02d:%02d" "$h" "$m" "$r"
  else
    printf -v out_ref "%02d:%02d" "$m" "$r"
  fi
}

# time_s_to_hms <seconds> [hour_width]
# Print formatted time string converted from seconds.
# Always returns 0.
time_s_to_hms() {
  local result
  _time_s_to_hms result "$@"
  printf '%s\n' "$result"
}

# _time_hms_to_s <out_ref> <hms>
# Convert mm:ss or hh:mm:ss to total seconds.
# Assumes <hms> is a valid time string.
# Always returns 0.
_time_hms_to_s() {
  local -n out_ref="$1"
  local t="$2"

  local parts=()
  IFS=: read -r -a parts <<< "$t"

  if (( ${#parts[@]} == 3 )); then
    out_ref=$(( 10#${parts[0]} * 3600 + 10#${parts[1]} * 60 + 10#${parts[2]} ))
  else
    out_ref=$(( 10#${parts[0]} * 60 + 10#${parts[1]} ))
  fi
}

# time_hms_to_s <hms>
# Print total seconds converted from time string.
# Always returns 0.
time_hms_to_s() {
  local result
  _time_hms_to_s result "$@"
  printf '%s\n' "$result"
}

# _time_convert <out_ref> <value> <from_unit> <to_unit>
# Convert time value between units: ms, s, m, h.
# Units must correspond to defined scale constants.
# Assumes units are valid.
# Always returns 0.
_time_convert() {
  local -n out_ref="$1"
  local value="$2"
  local from="$3"
  local to="$4"

  local from_scale="__TIME_SCALE_${from}"
  local to_scale="__TIME_SCALE_${to}"

  # shellcheck disable=SC2034
  out_ref=$(( value * ${!from_scale} / ${!to_scale} ))
}

# time_convert <value> <from_unit> <to_unit>
# Print converted time value between units.
# Always returns 0.
time_convert() {
  local result
  _time_convert result "$@"
  printf '%s\n' "$result"
}
