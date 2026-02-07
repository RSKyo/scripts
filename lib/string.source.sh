#!/usr/bin/env bash
#
# Source-only library: string helpers
# Small, practical string utilities used across scripts.
#

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__STRING_SOURCED+x}" ]] && return 0
__STRING_SOURCED=1

# -------------------------------------------------
# Public API
# -------------------------------------------------

# Remove leading and trailing whitespace
string_trim() {
  local text="$1"
  [[ -n "$text" ]] || return 0

  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "$text"
}

# Extract substring by 1-based positions (inclusive)
string_substr() {
  local text="$1"
  local start="$2"
  local end="$3"

  [[ -n "$text" ]] || return 0
  [[ "$start" =~ ^[0-9]+$ ]] || { printf '%s\n' "$text"; return 0; }

  (( start < 1 )) && start=1
  local offset=$((start - 1))

  if [[ -z "$end" ]]; then
    printf '%s\n' "${text:$offset}"
    return 0
  fi

  [[ "$end" =~ ^[0-9]+$ ]] || { printf '%s\n' "${text:$offset}"; return 0; }
  (( end < start )) && { printf '%s\n' ""; return 0; }

  local length=$((end - start + 1))
  printf '%s\n' "${text:$offset:$length}"
}

# Normalize string for filesystem-safe usage
string_normalize() {
  local text="$1"
  [[ -n "$text" ]] || return 0

  text="${text//\\/ }"
  text="${text//\// }"
  text="${text//:/ }"
  text="${text//\*/ }"
  text="${text//\?/ }"
  text="${text//\"/ }"
  text="${text//</ }"
  text="${text//>/ }"
  text="${text//|/ }"

  while [[ "$text" == *"  "* ]]; do
    text="${text//  / }"
  done

  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "$text"
}

# Generate a random alphanumeric string
string_random() {
  local len="${1:-8}"

  [[ "$len" =~ ^[0-9]+$ ]] || {
    echo "[string_random] length must be a positive integer" >&2
    return 1
  }

  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len"
  printf '\n'
}
