#!/usr/bin/env bash
# string.source.sh
# String utilities.
# - _string_* : parameter-based primitives (nameref output)
# - string_*  : stream wrappers (stdin → stdout)
# - All indices are 1-based and inclusive.

# shellcheck disable=SC1091,SC2034

# Prevent multiple sourcing
[[ -n "${__STRING_SOURCED+x}" ]] && return 0
__STRING_SOURCED=1

# Internal field separator.
readonly __STRING_SEP=$'\x1f'

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/num.source.sh"

# _string_trim <out_ref> <input>
# Trim leading and trailing whitespace.
# Result written to <out_ref>.
_string_trim() {
  local -n out_ref="$1"
  local input="$2"

  [[ -n "$input" ]] || { out_ref=''; return 0; }

  input="${input#"${input%%[![:space:]]*}"}"
  input="${input%"${input##*[![:space:]]}"}"

  out_ref="$input"
}

# string_trim
# Trim whitespace for each stdin line.
string_trim() {
  local result line
  while IFS= read -r line; do
    _string_trim result "$line"
    printf '%s\n' "$result"
  done
}

# _string_slice <out_ref> <input> <start> <end>
# Extract substring by 1-based inclusive indices.
# Out-of-range indices are normalized.
_string_slice() {
  local -n out_ref="$1"
  local input="$2"
  local start="$3"
  local end="$4"

  [[ -n "$input" ]] || { out_ref=''; return 0; }

  local len=${#input}
  { num_is_int "$start" && num_between "$start" 1 "$len"; } || start=1
  { num_is_int "$end"   && num_between "$end"   1 "$len"; } || end="$len"
  (( start <= end )) || { out_ref=''; return 0; }

  out_ref="${input:$((start - 1)):$((end - start + 1))}"
}

# string_slice <start> <end>
# Apply slice to each stdin line.
string_slice() {
  local result line
  while IFS= read -r line; do
    _string_slice result "$line" "$@"
    printf '%s\n' "$result"
  done
}

# _string_normalize <out_ref> <input>
# Replace filesystem-reserved characters with space,
# collapse duplicate spaces, and trim.
_string_normalize() {
  local -n out_ref="$1"
  local input="$2"

  [[ -n "$input" ]] || { out_ref=''; return 0; }

  input="${input//\\/ }"
  input="${input//\// }"
  input="${input//:/ }"
  input="${input//\*/ }"
  input="${input//\?/ }"
  input="${input//\"/ }"
  input="${input//</ }"
  input="${input//>/ }"
  input="${input//|/ }"

  while [[ "$input" == *"  "* ]]; do
    input="${input//  / }"
  done

  input="${input#"${input%%[![:space:]]*}"}"
  input="${input%"${input##*[![:space:]]}"}"

  out_ref="$input"
}

# string_normalize
# Normalize each stdin line.
string_normalize() {
  local result line
  while IFS= read -r line; do
    _string_normalize result "$line"
    printf '%s\n' "$result"
  done
}

# string_random [length]
# Generate random alphanumeric string.
# Default length: 8.
string_random() {
  local len="${1:-8}"

  [[ "$len" =~ ^[0-9]+$ ]] || len=8
  (( len > 0 )) || len=8

  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len"
  printf '\n'
}

# _string_expand <out_ref> <input> <regex> [from_ratio] [to_ratio]
# Match within ratio-defined window and split into:
#   left <SEP> match <SEP> right
# Window ratios range from 0 to 1.
# Result written to <out_ref>.
_string_expand() {
  local -n out_ref="$1"
  local input="${2?_string_expand: missing input}"
  local regex="${3:?_string_expand: missing regex}"
  local win_from_ratio="$4"
  local win_to_ratio="$5"

  
  [[ -n "$input" ]] || {
    printf -v out_ref '%s%s%s%s%s' \
    '' "$__STRING_SEP" '' "$__STRING_SEP" ''
    return 0
  }

  # Normalize ratio range.
  if [[ -z "$win_from_ratio" ]] || 
     ! num_between "$win_from_ratio" 0 1 || 
     num_cmp "$win_from_ratio" eq 1; then
    win_from_ratio=0
  fi

  if [[ -z "$win_to_ratio" ]] || 
     ! num_between "$win_to_ratio" 0 1 || 
     num_cmp "$win_to_ratio" eq 0; then
    win_to_ratio=1
  fi

  num_cmp "$win_from_ratio" lt "$win_to_ratio" || {
    win_from_ratio=0
    win_to_ratio=1
  }

  # Convert ratios to positions
  local len=${#input}
  local win_from_pos win_to_pos 
  local win_left win win_right
  local left="$input" match='' right=''

  _num_product win_from_pos "$len" "$win_from_ratio" 0
  _num_product win_to_pos   "$len" "$win_to_ratio"   0

  # Match within window and split.
  if (( win_from_pos < win_to_pos )) ; then
    win_left="${input:0:win_from_pos}"
    win="${input:win_from_pos:win_to_pos-win_from_pos}"
    win_right="${input:win_to_pos}"
     if [[ -n "$win" && "$win" =~ $regex ]]; then
        match="${BASH_REMATCH[0]}"
        left="$win_left${win%%"$match"*}"
        right="${win#*"$match"}$win_right"
      fi
  fi

  printf -v out_ref '%s%s%s%s%s' \
    "$left" "$__STRING_SEP" "$match" "$__STRING_SEP" "$right"

  return 0
}

# string_expand <regex> [win_from_ratio] [win_to_ratio]
# Apply expand to each stdin line.
string_expand() {
  local result line
  while IFS= read -r line; do
    _string_expand result "$line" "$@"
    printf '%s\n' "$result"
  done
}
