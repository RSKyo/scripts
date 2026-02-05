#!/usr/bin/env bash
# Source-only library: time unit conversion
#
# This module provides pure numeric unit conversions for time.
# It does NOT parse string expressions like "mm:ss" or "hh:mm:ss".
#
# Conversions covered:
#   - milliseconds <-> seconds
#   - seconds <-> minutes
#   - seconds <-> hours
#
# Design principles:
#   - numeric in, numeric out
#   - no side effects
#   - stdout only
#   - suitable for ffprobe / yt-dlp durations

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__TIME_UNIT_SOURCED+x}" ]] && return 0
__TIME_UNIT_SOURCED=1

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

