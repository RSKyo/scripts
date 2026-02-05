#!/usr/bin/env bash
# String helpers: random string generation
#
# Provides:
#   string_random [length]
#
# Behavior:
# - generate a random alphanumeric string
# - character set: A–Z a–z 0–9
# - default length: 8
#
# Notes:
# - Generates opaque random strings with no implied semantics
# - Intended for temporary names, suffixes, or identifiers
# - Source-only module
# - Bash 3.2 compatible (macOS system default)
# - Uses /dev/urandom (not intended for cryptographic guarantees)
# - stdout: generated string
# - stderr: validation errors only

# -------------------------------------------------
# Prevent multiple sourcing
# -------------------------------------------------
[[ -n "${__STRING_RANDOM_SOURCED+x}" ]] && return 0
__STRING_RANDOM_SOURCED=1

# -------------------------------------------------
# Public API
# -------------------------------------------------
string_random() {
  local len="${1:-8}"

  # basic validation: positive integer
  [[ "$len" =~ ^[0-9]+$ ]] || {
    echo "[string_random] length must be a positive integer" >&2
    return 1
  }

  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len"
  printf '\n'
}
