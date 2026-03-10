#!/usr/bin/env bash
# Source-only library: lib/string
# shellcheck disable=SC1091,SC2016

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__STRING_SOURCED+x}" ]] && return 0
__STRING_SOURCED=1

# --- Dependencies ------------------------------------------------------------

# Dependencies (bootstrap must be sourced by the entry script)
source "$LIB_DIR/num.source.sh"

# --- Internal Helpers --------------------------------------------------------

__string_split_by_ratio() {
  local -n _left_ref="$1"
  local -n _center_ref="$2"
  local -n _right_ref="$3"

  local _input="$4"
  local _ratio_start="$5"
  local _ratio_end="$6"

  local len=${#_input}
  local boundary_from boundary_to

  boundary_from=$(num_product "$len" "$_ratio_start" 0)
  boundary_to=$(num_product "$len" "$_ratio_end" 0)

  _left_ref="${_input:0:boundary_from}"
  _center_ref="${_input:boundary_from:boundary_to-boundary_from}"
  _right_ref="${_input:boundary_to}"
}

__string_split_by_regex() {
  local -n _left_ref="$1"
  local -n _match_ref="$2"
  local -n _right_ref="$3"

  local _input="$4"
  local _regex="$5"

  if [[ "$_input" =~ $_regex ]]; then
    _match_ref="${BASH_REMATCH[0]}"
    _left_ref="${_input%%"$_match_ref"*}"
    _right_ref="${_input#*"$_match_ref"}"
  else
    _match_ref=''
    _left_ref="$_input"
    _right_ref="$_input"
  fi
}

# --- Public API --------------------------------------------------------------

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
  local replacement="${2-}"

  input="${input//\\/"$replacement"}"
  input="${input//\//"$replacement"}"
  input="${input//:/"$replacement"}"
  input="${input//\*/"$replacement"}"
  input="${input//\?/"$replacement"}"
  input="${input//\"/"$replacement"}"
  input="${input//</"$replacement"}"
  input="${input//>/"$replacement"}"
  input="${input//|/"$replacement"}"

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
  
  printf '%s%s%s%s%s\n' "$left" "$SEP" "$match" "$SEP" "$right"
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
