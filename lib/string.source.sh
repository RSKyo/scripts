#!/usr/bin/env bash
# string.source.sh
# String utilities module.

# shellcheck disable=SC1091,SC2034

# Prevent multiple sourcing
[[ -n "${__STRING_SOURCED+x}" ]] && return 0
__STRING_SOURCED=1

# Internal field separator.
readonly __STRING_SEP=$'\x1f'

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/num.source.sh"

# -------------------------------------------------
# Internal Helpers (name-ref only)
# -------------------------------------------------

____string_window() {
  local -n prefix="$1"
  local -n window="$2"
  local -n suffix="$3"

  local input="$4"
  local ratio_start="$5"
  local ratio_end="$6"

  local len=${#input}
  local boundary_from boundary_to

  boundary_from=$(num_product "$len" "$ratio_start" 0)
  boundary_to=$(num_product "$len" "$ratio_end" 0)

  prefix="${input:0:boundary_from}"
  window="${input:boundary_from:boundary_to-boundary_from}"
  suffix="${input:boundary_to}"
}

____string_match() {
  local -n left="$1"
  local -n match="$2"
  local -n right="$3"

  local input="$4"
  local regex="$5"

  if [[ "$input" =~ $regex ]]; then
    match="${BASH_REMATCH[0]}"
    left="${input%%"$match"*}"
    right="${input#*"$match"}"
  else
    left="$input"
    match=''
    right=''
  fi
}

__string_window() {
  local -n _out_prefix="$1"
  local -n _out_window="$2"
  local -n _out_suffix="$3"
  shift 3
  local _inner_prefix
  local _inner_window
  local _inner_suffix
  ____string_window \
    _inner_prefix \
    _inner_window \
    _inner_suffix \
    "$@"
  _out_prefix="$_inner_prefix"
  _out_window="$_inner_window"
  _out_suffix="$_inner_suffix"
}

__string_match() {
  local -n _out_left="$1"
  local -n _out_match="$2"
  local -n _out_right="$3"
  shift 3
  local _inner_left
  local _inner_match
  local _inner_right
  ____string_match \
    _inner_left \
    _inner_match \
    _inner_right \
    "$@"
  _out_left="$_inner_left"
  _out_match="$_inner_match"
  _out_right="$_inner_right"
}

# -------------------------------------------------
# Public API (stdout interface)
# -------------------------------------------------

# Expose internal separator as public constant (read-only).
readonly STRING_SEP="$__STRING_SEP"

# string_trim <input>
# Trim leading and trailing whitespace.
string_trim() {
  local input="${1-}"

  input="${input#"${input%%[![:space:]]*}"}"
  input="${input%"${input##*[![:space:]]}"}"

  printf '%s\n' "$input"
}

# string_slice <input> <start> <end>
# Extract substring by 1-based inclusive indices.
string_slice() {
  local input="${1-}"
  local start="${2-1}"
  local end="${3-${#input}}"

  num_is_pos_int "$start" || return 1
  num_is_pos_int "$end" || return 1
  
  local offset=$((start - 1))
  local length=$((end - start + 1))

  printf '%s\n' "${input:offset:length}"
}

# string_normalize <input>
# Replace filesystem-reserved characters with space,
# collapse duplicate spaces, and trim.
string_normalize() {
  local input="${1-}"

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

  printf '%s\n' "$input"
}

# string_random <len>
# Generate a pseudo-random alphanumeric string.
# - len: positive integer length (default: 8)
# - Character set: A–Z a–z 0–9
# - Random source: num_random_int32 (pseudo-random, not secure)
# - stdout: generated string
string_random() {
  local len="${1:-8}"
  local chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  local max=${#chars}
  local result=''
  local i r

  num_is_pos_int "$len" || len=8

  for (( i=0; i<len; i++ )); do
    r=$(num_random_int32)
    result+="${chars:r%max:1}"
  done

  printf '%s\n' "$result"
}

# string_expand <input> <regex> [from_ratio] [to_ratio]
# Return structured result: left<SEP>match<SEP>right.
# If ratio arguments are provided, match within that window only.
string_expand() {
  local input="${1-}"
  local regex="${2:?string_match: missing regex}"
  local ratio_start="${3-}"
  local ratio_end="${4-}"

  local sep="$__STRING_SEP"

  [[ -z "$input" ]] && {
    printf '%s%s%s%s%s\n' '' "$sep" '' "$sep" ''
    return 0
  }

  local left match right

  if [[ -n "$ratio_start" && -n "$ratio_end" ]]; then
    local prefix window suffix

    __string_window prefix window suffix "$input" "$ratio_start" "$ratio_end"
    __string_match left match right "$window" "$regex"

    left="$prefix$left"
    right="$right$suffix"
  else
    __string_match left match right "$input" "$regex"
  fi

  printf '%s%s%s%s%s\n' "$left" "$sep" "$match" "$sep" "$right"

  return 0
}

# string_match <input> <regex> [from_ratio] [to_ratio]
# Return first matched substring.
# If ratio arguments are provided, match within that window only.
string_match() {
  local input="${1-}"
  local regex="${2:?string_match: missing regex}"
  local ratio_start="${3-}"
  local ratio_end="${4-}"

  [[ -z "$input" ]] && { printf '\n'; return 0; }

  local left match right

  if [[ -n "$ratio_start" && -n "$ratio_end" ]]; then
    local prefix window suffix

    __string_window prefix window suffix "$input" "$ratio_start" "$ratio_end"
    __string_match left match right "$window" "$regex"
  else
    __string_match left match right "$input" "$regex"
  fi

  printf '%s\n' "$match"

  return 0
}
