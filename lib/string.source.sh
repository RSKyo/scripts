#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
#
# string.source.sh
#
# String helper functions.
#

# Prevent multiple sourcing
[[ -n "${__STRING_SOURCED+x}" ]] && return 0
__STRING_SOURCED=1

# string_trim <string>
#
# Remove leading and trailing whitespace.
#
# - stdout: trimmed string
# - return: always 0
string_trim() {
  local text="$1"
  [[ -n "$text" ]] || return 0

  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "$text"
}

# string_substr <string> <start> [end]
#
# Extract a substring using 1-based positions (inclusive).
#
# - <start> is 1-based; values < 1 are clamped to 1
# - <end> is optional; if omitted, returns from <start> to end
#
# - stdout: extracted substring
# - return: always 0
#
# Notes:
# - Non-numeric <start>/<end> values are ignored gracefully.
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

# string_regex_index <string> <regex>
#
# Return the 0-based index of the first regex match.
#
# - stdout: match index (0-based), empty if no match
# - return: always 0
#
# Notes:
# - Regex matching is performed by Perl with UTF-8 enabled.
string_regex_index() {
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
#
# Normalize a string for filesystem-safe usage.
#
# - Replaces filesystem-unsafe characters with spaces
# - Collapses repeated spaces
# - Trims leading and trailing whitespace
#
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
#
# Generate a random alphanumeric string.
#
# - <length> defaults to 8
# - stdout: random string
# - return: always 0
string_random() {
  local len="${1:-8}"

  # normalize length
  [[ "$len" =~ ^[0-9]+$ ]] || len=8
  (( len > 0 )) || len=8

  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len"
  printf '\n'
}

