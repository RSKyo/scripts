#!/usr/bin/env bash
# String helpers: normalization for display / filename-like strings
#
# Provides:
#   string_normalize <string>
#
# Behavior:
# - replace illegal or unsupported characters with spaces
# - collapse consecutive spaces into one
# - trim leading and trailing whitespace
#
# Notes:
# - Intended for display text or filename-like strings
# - Source-only module
# - Bash 3.2 compatible (macOS system default)
# - Pure helper: no I/O, no external commands

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__STRING_NORMALIZE_SOURCED+x}" ]] && return 0
__STRING_NORMALIZE_SOURCED=1

# -------------------------------------------------
# Public API
# -------------------------------------------------
string_normalize() {
  local text="$1"
  [[ -n "$text" ]] || return 0

  # replace illegal characters with space
  text="${text//\\/ }"
  text="${text//\// }"
  text="${text//:/ }"
  text="${text//\*/ }"
  text="${text//\?/ }"
  text="${text//\"/ }"
  text="${text//</ }"
  text="${text//>/ }"
  text="${text//|/ }"

  # collapse consecutive spaces
  while [[ "$text" == *"  "* ]]; do
    text="${text//  / }"
  done

  # trim result
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "$text"
}

