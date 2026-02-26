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

____string_split_by_ratio() {
  local -n left="$1"
  local -n center="$2"
  local -n right="$3"

  local input="$4"
  local ratio_start="$5"
  local ratio_end="$6"

  local len=${#input}
  local boundary_from boundary_to

  boundary_from=$(num_product "$len" "$ratio_start" 0)
  boundary_to=$(num_product "$len" "$ratio_end" 0)

  left="${input:0:boundary_from}"
  center="${input:boundary_from:boundary_to-boundary_from}"
  right="${input:boundary_to}"
}

____string_split_by_regex() {
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
    right="$input"
  fi
}

__string_split_by_ratio() {
  local -n _out_left="$1"
  local -n _out_center="$2"
  local -n _out_right="$3"
  shift 3
  local _inner_left
  local _inner_center
  local _inner_right
  ____string_split_by_ratio \
    _inner_left \
    _inner_center \
    _inner_right \
    "$@"
  _out_left="$_inner_left"
  _out_center="$_inner_center"
  _out_right="$_inner_right"
}

__string_split_by_regex() {
  local -n _out_left="$1"
  local -n _out_match="$2"
  local -n _out_right="$3"
  shift 3
  local _inner_left
  local _inner_match
  local _inner_right
  ____string_split_by_regex \
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

# string_expand <input> <pattern> [--window from to]
# Expand a string by pattern and output structured result.
string_expand() {
  # --- Params ---
  local input="${1-}"
  local regex="${2:?string_expand: missing regex}"
  shift 2
  local ratio_start=''
  local ratio_end=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) 
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  # --- Behavior ---
  local sep="$__STRING_SEP"
  local prefix='' window='' suffix=''
  local left='' match='' right=''

  if [[ -n "$input" && -n "$ratio_start" && -n "$ratio_end" ]]; then
    __string_split_by_ratio prefix window suffix \
      "$input" "$ratio_start" "$ratio_end"

    input="$window"
  fi

  if [[ -n "$input" ]]; then
    __string_split_by_regex left match right "$input" "$regex"
  fi

  left="$prefix$left"
  right="$right$suffix"
  
  printf '%s%s%s%s%s\n' "$left" "$sep" "$match" "$sep" "$right"
}

# string_expand_side <input> <pattern> [--window from to] [--side value]
# Expand a string and output the selected part.
string_expand_side() {
  # --- Params ---
  local input="${1-}"
  local regex="${2:?string_expand_side: missing regex}"
  shift 2
  local ratio_start=''
  local ratio_end=''
  local side='left'

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) 
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --side) 
        shift
        [[ $# -ge 1 ]] || return 2
        case "$1" in
          left|right) side="$1" ;;
          *) return 2 ;;
        esac
        shift
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  # --- Behavior ---
  local prefix='' window='' suffix=''
  local left='' match='' right=''

  if [[ -n "$input" && -n "$ratio_start" && -n "$ratio_end" ]]; then
    __string_split_by_ratio prefix window suffix \
      "$input" "$ratio_start" "$ratio_end"

    input="$window"
  fi

  if [[ -n "$input" ]]; then
    __string_split_by_regex left match right "$input" "$regex"
  fi

  left="$prefix$left"
  right="$right$suffix"

  if [[ "$side" == 'left' ]]; then
    printf '%s\n' "$left"
  else
    printf '%s\n' "$right"
  fi
}

# string_match <input> <pattern> [--window from to]
# Return 0 if input matches pattern.
string_match() {
  # --- Params ---
  local input="${1-}"
  local regex="${2:?string_match: missing regex}"
  shift 2
  local ratio_start=''
  local ratio_end=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window)
        shift
        [[ $# -ge 2 ]] || return 2
        ratio_start="$1"
        ratio_end="$2"
        shift 2
        ;;
      --) shift; break ;;
      *) return 2 ;;
    esac
  done

  # --- Behavior ---
  [[ -z "$input" ]] && return 1

  local window match _
  
  if [[ -n "$ratio_start" && -n "$ratio_end" ]]; then
    __string_split_by_ratio _ window _ \
      "$input" "$ratio_start" "$ratio_end"
    [[ -z "$window" ]] && return 1

    input="$window"
  fi

  __string_split_by_regex _ match _ \
    "$input" "$regex"
  [[ -z "$match" ]] && return 1

  return 0
}
