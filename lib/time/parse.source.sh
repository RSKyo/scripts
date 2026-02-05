#!/usr/bin/env bash
# Source-only library: time parsing
#
# This module parses time expressions into seconds.
# It does NOT perform generic unit conversions (ms <-> s etc.).
#
# Parsers covered:
#   - "mm:ss"     -> seconds
#   - "hh:mm:ss"  -> seconds
#
# Notes:
#   - Leading zeros are supported (e.g., "01:02").
#   - Uses 10# prefix to avoid octal interpretation in arithmetic context.

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__TIME_PARSE_SOURCED+x}" ]] && return 0
__TIME_PARSE_SOURCED=1

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
