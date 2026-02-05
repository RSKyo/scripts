#!/usr/bin/env bash
# Source-only library: time formatting
#
# This module formats integer seconds into common timestamp strings.
# It does NOT parse time expressions (see lib/time/parse.source.sh).
# It does NOT do unit conversions (see lib/time/unit.source.sh).
#
# Formatters covered:
#   - seconds -> "mm:ss"       (minutes may exceed 59)
#   - seconds -> "hh:mm:ss"    (hours included, minutes and seconds are 00-59)
#
# Notes:
#   - Inputs are treated as non-negative integers. Negative inputs are clamped to 0.
#   - No floating-point support in this module (keep it stable in pure bash).

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__TIME_FORMAT_SOURCED+x}" ]] && return 0
__TIME_FORMAT_SOURCED=1

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
