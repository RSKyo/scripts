#!/usr/bin/env bash

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__TIME_SOURCED+x}" ]] && return 0
__TIME_SOURCED=1

# -----------------------------------------------------------------------------
# time_format_s_to_mmss
#
# Convert integer seconds to "mm:ss".
# - Minutes are not capped (e.g., 3723s -> "62:03").
#
# Usage:
#   time_format_s_to_mmss 0      -> 00:00
#   time_format_s_to_mmss 201    -> 03:21
#   time_format_s_to_mmss 3723   -> 62:03
# -----------------------------------------------------------------------------
time_format_s_to_mmss() {
  local s="${1:-0}"

  # Clamp negative to 0
  if [[ "$s" =~ ^- ]]; then s=0; fi

  local m=$(( s / 60 ))
  local r=$(( s % 60 ))

  printf '%02d:%02d\n' "$m" "$r"
}

# -----------------------------------------------------------------------------
# time_format_s_to_hhmmss
#
# Convert integer seconds to "hh:mm:ss".
# - Hours can be >= 0, minutes and seconds are 00-59.
#
# Usage:
#   time_format_s_to_hhmmss 0      -> 00:00:00
#   time_format_s_to_hhmmss 3723   -> 01:02:03
# -----------------------------------------------------------------------------
time_format_s_to_hhmmss() {
  local s="${1:-0}"

  # Clamp negative to 0
  if [[ "$s" =~ ^- ]]; then s=0; fi

  local h=$(( s / 3600 ))
  local rem=$(( s % 3600 ))
  local m=$(( rem / 60 ))
  local r=$(( rem % 60 ))

  printf '%02d:%02d:%02d\n' "$h" "$m" "$r"
}

# -----------------------------------------------------------------------------
# time_format_s_to_auto
#
# Convert integer seconds to:
#   - "mm:ss" when < 3600
#   - "hh:mm:ss" when >= 3600
#
# Usage:
#   time_format_s_to_auto 201    -> 03:21
#   time_format_s_to_auto 3723   -> 01:02:03
# -----------------------------------------------------------------------------
time_format_s_to_auto() {
  local s="${1:-0}"

  # Clamp negative to 0
  if [[ "$s" =~ ^- ]]; then s=0; fi

  if (( s >= 3600 )); then
    time_format_s_to_hhmmss "$s"
  else
    time_format_s_to_mmss "$s"
  fi
}

# -----------------------------------------------------------------------------
# time_parse_hms_to_s
#
# Parse "mm:ss" or "hh:mm:ss" into integer seconds.
#
# Usage:
#   time_parse_hms_to_s "03:21"     -> 201
#   time_parse_hms_to_s "1:02:03"   -> 3723
#
# Output:
#   - seconds (integer) to stdout
# Return:
#   - 0 always (prints 0 for empty input)
# -----------------------------------------------------------------------------
time_parse_hms_to_s() {
  local t="${1:-}"
  local IFS=":"
  local h m s

  [[ -z "$t" ]] && { printf '0\n'; return 0; }

  # Supports mm:ss / hh:mm:ss
  read -r h m s <<< "$t"

  if [[ -z "${s:-}" ]]; then
    # mm:ss
    printf '%d\n' $((10#$h * 60 + 10#$m))
  else
    # hh:mm:ss
    printf '%d\n' $((10#$h * 3600 + 10#$m * 60 + 10#$s))
  fi
}

# -----------------------------------------------------------------------------
# milliseconds <-> seconds
# -----------------------------------------------------------------------------

time_unit_ms_to_s() {
  local ms="$1"
  [[ -z "$ms" ]] && return 0
  # integer division, truncate
  printf '%d\n' $(( ms / 1000 ))
}

time_unit_s_to_ms() {
  local s="$1"
  [[ -z "$s" ]] && return 0
  printf '%d\n' $(( s * 1000 ))
}

# -----------------------------------------------------------------------------
# seconds <-> minutes
# -----------------------------------------------------------------------------

time_unit_min_to_s() {
  local min="$1"
  [[ -z "$min" ]] && return 0
  printf '%d\n' $(( min * 60 ))
}

time_unit_s_to_min() {
  local s="$1"
  [[ -z "$s" ]] && return 0
  # integer division, truncate
  printf '%d\n' $(( s / 60 ))
}

# -----------------------------------------------------------------------------
# seconds <-> hours
# -----------------------------------------------------------------------------

time_unit_h_to_s() {
  local h="$1"
  [[ -z "$h" ]] && return 0
  printf '%d\n' $(( h * 3600 ))
}

time_unit_s_to_h() {
  local s="$1"
  [[ -z "$s" ]] && return 0
  # integer division, truncate
  printf '%d\n' $(( s / 3600 ))
}