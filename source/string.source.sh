#!/usr/bin/env bash
# Source-only library: string
# Provides:
#   string_ltrim <string>
#   string_rtrim <string>
#   string_trim  <string>
#   string_sanitize  <string>
# - stdout: transformed string
# - stderr: none
# - return: always 0

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "[ERROR] $(basename "${BASH_SOURCE[0]}") must be sourced, not executed." >&2
  exit 1
fi

__STRING_SANITIZE_RULES=(
  "/"   " - "  "path separator"
  "\\"  " - "  "windows path separator"
  ":"   " - "  "title separator"
  "|"   " - "  "pipe"

  "*"   "_"    "wildcard"
  "?"   "_"    "question mark"
  "\""  "'"    "double quote"

  "<"   "("    "left angle"
  ">"   ")"    "right angle"
)

string_ltrim() {
  local text="$1"

  [[ -n "$text" ]] || return 0

  text="${text#"${text%%[![:space:]]*}"}"

  printf '%s\n' "$text"
}

string_rtrim() {
  local text="$1"

  [[ -n "$text" ]] || return 0

  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "$text"
}

string_trim() {
  local text="$1"

  [[ -n "$text" ]] || return 0

  text="${text#"${text%%[![:space:]]*}"}"
  text="${text%"${text##*[![:space:]]}"}"

  printf '%s\n' "$text"
}

string_sanitize() {
  local text="$1"
  [[ -n "$text" ]] || return 0

  local i pattern replacement
  local total=${#__STRING_SANITIZE_RULES[@]}

  text="$(string_trim "$text")"

  # apply rules
  for ((i = 0; i < total; i += 3)); do
    pattern="${__STRING_SANITIZE_RULES[i]}"
    replacement="${__STRING_SANITIZE_RULES[i+1]}"
    text="${text//"$pattern"/"$replacement"}"
  done

  # collapse spaces
  text="$(printf '%s\n' "$text" | tr -s ' ')"

  printf '%s\n' "$text"
}
