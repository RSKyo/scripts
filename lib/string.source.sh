#!/usr/bin/env bash
# String manipulation utilities for shell scripts.
# Provides functions for trimming, substring extraction, regex matching, normalization, and random string generation.
# Author: Zhang Hao
# Email:  
# License: MIT 
# Usage:
#   source string.source.sh # to load the functions into your script.
# Note: These functions are designed to be POSIX-compliant and should work in any POSIX-compatible shell, including bash, sh, and zsh.
# Functions:
#   - string_trim <string>
#   - string_slice <string> <start> [end]
#   - string_search <string> <regex>
#   - string_normalize <string>
#   - string_random [length] 



# Prevent multiple sourcing
[[ -n "${__STRING_SOURCED+x}" ]] && return 0
__STRING_SOURCED=1

# string_trim <string>
# Trim leading and trailing whitespace from a string.
# - stdout: trimmed string
# - return: always 0
string_trim() {
  local text="$1"
  [[ -n "$text" ]] || return 0

  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "$text"
}

# string_slice <string> <start> [end]
# Extract a substring from a string.
# - <start> is 1-based index of the first character to include
# - <end> is 1-based index of the last character to include (optional)
# - stdout: extracted substring
# - return: always 0
string_slice() {
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

# string_search <string> <regex>
# Find the index of the first match of a regex in a string.
# - stdout: 0-based index of the first match, or empty if no match
# - return: always 0
string_search() {
  local text="$1"
  local regex="$2"

  __perl '
    use strict;
    use warnings;
    use utf8;

    my ($s, $re) = @ARGV;

    if ($s =~ /$re/) {
      print $-[0];
    }
  ' "$text" "$regex"

  return 0
}

# string_normalize <string>
# Normalize a string by replacing certain characters with spaces and collapsing multiple spaces.
# - stdout: normalized string
# - return: always 0
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

# string_random [length]
# Generate a random alphanumeric string of the specified length (default: 8).
# - stdout: random string
# - return: always 0
string_random() {
  local len="${1:-8}"

  [[ "$len" =~ ^[0-9]+$ ]] || len=8
  (( len > 0 )) || len=8

  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len"
  printf '\n'
}

