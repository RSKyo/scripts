#!/usr/bin/env bash
# String helpers: whitespace trimming
#
# Provides:
#   string_ltrim <string>   # remove leading whitespace
#   string_rtrim <string>   # remove trailing whitespace
#   string_trim  <string>   # remove leading and trailing whitespace
#
# Notes:
# - Source-only module (intended to be sourced, not executed)
# - Bash 3.2 compatible (macOS system default)
# - Pure helpers: no side effects, no external commands
# - stdout: transformed string
# - stderr: none

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__STRING_TRIM_SOURCED+x}" ]] && return 0
__STRING_TRIM_SOURCED=1

# -------------------------------------------------
# Public API
# -------------------------------------------------
string_ltrim() {
  local text="$1"
  [[ -n "$text" ]] || return 0

  # remove leading whitespace
  text="${text#"${text%%[![:space:]]*}"}"

  printf '%s\n' "$text"
}

string_rtrim() {
  local text="$1"
  [[ -n "$text" ]] || return 0

  # remove trailing whitespace
  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "$text"
}

string_trim() {
  local text="$1"
  [[ -n "$text" ]] || return 0

  # left
  text="${text#"${text%%[![:space:]]*}"}"
  # right
  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "$text"
}

