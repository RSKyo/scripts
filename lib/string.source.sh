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

# __string_match_expand <out_var> <input> <regex> <from_idx> <to_idx>
# Core matcher (internal use).
# - Slice input using half-open boundary indices [from_idx, to_idx).
# - Search regex within the sliced window.
# - Output formatted string: left<SEP>match<SEP>right
# - out_var is a nameref target.
__string_match_expand() {
  local -n out="$1"
  local input="$2"
  local regex="$3"
  local from_idx="$4"
  local to_idx="$5"

  local sep="$__STRING_SEP"
  local prefix window suffix
  local left="$input" match='' right=''

  if (( from_idx < to_idx )); then
    prefix="${input:0:from_idx}"
    window="${input:from_idx:to_idx-from_idx}"
    suffix="${input:to_idx}"

    logd '----------'
    logd "string: $input"
    logd "from_idx: $from_idx, to_idx: $to_idx, window: $window"
    logd "regex: $regex"

    if [[ -n "$window" && "$window" =~ $regex ]]; then
      match="${BASH_REMATCH[0]}"
      left="$prefix${window%%"$match"*}"
      right="${window#*"$match"}$suffix"
    fi

    logd "match: $match"
    logd "left: $left"
    logd "right: $right"

  fi

  printf -v out '%s%s%s%s%s' "$left" "$sep" "$match" "$sep" "$right"
}

# __string_match_expand_into <out_var> <input> <regex> <from_idx> <to_idx>
# Safe wrapper for __string_match_expand.
# - Isolates internal variable names to avoid nameref collisions.
# - Writes result into out_var.
__string_match_expand_into() {
  local -n out="$1"
  local __string_match_expand_input="$2"
  local __string_match_expand_regex="$3"
  local __string_match_expand_from_idx="$4"
  local __string_match_expand_to_idx="$5"

  local __string_match_out

  __string_match_expand __string_match_out \
    "$__string_match_expand_input" \
    "$__string_match_expand_regex" \
    "$__string_match_expand_from_idx" \
    "$__string_match_expand_to_idx"
  
  # shellcheck disable=SC2034
  out="$__string_match_out"
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
# Window is defined by ratio range (default 0–1).
string_expand() {
  local input="${1-}"
  local regex="${2:?string_expand: missing regex}"
  local ratio_start="${3:-0}"
  local ratio_end="${4:-1}"
  local sep="$__STRING_SEP"

  if [[ -z "$input" ]]; then 
    printf '%s%s%s%s%s\n' '' "$sep" '' "$sep" ''
    return 0
  fi

  # Normalize ratios
  if [[ "$ratio_start" != '0' || "$ratio_end" != '1' ]]; then
    num_between "$ratio_start" 0 1 --right-open || ratio_start=0
    num_between "$ratio_end" 0 1 --left-open || ratio_end=1
    num_cmp "$ratio_start" lt "$ratio_end" || {
      ratio_start=0
      ratio_end=1
    }
  fi

  local len=${#input}
  local from_boundary to_boundary expanded

  from_boundary=$(num_product "$len" "$ratio_start" 0)
  to_boundary=$(num_product "$len" "$ratio_end" 0)
  
  __string_match_expand_into expanded \
    "$input" "$regex" "$from_boundary" "$to_boundary"

  printf '%s\n' "$expanded"
  
  return 0
}

# string_match <input> <regex> [from_ratio] [to_ratio]
# Return first matched substring within ratio window.
# Window is defined by ratio range (default 0–1).
string_match() {
  local input="${1-}"
  local regex="${2:?string_match: missing regex}"
  local ratio_start="${3:-0}"
  local ratio_end="${4:-1}"
  local sep="$__STRING_SEP"

  if [[ -z "$input" ]]; then 
    printf '%s\n' ''
    return 0
  fi

  # Normalize ratios
  if [[ "$ratio_start" != '0' || "$ratio_end" != '1' ]]; then
    num_between "$ratio_start" 0 1 --right-open || ratio_start=0
    num_between "$ratio_end" 0 1 --left-open || ratio_end=1
    num_cmp "$ratio_start" lt "$ratio_end" || {
      ratio_start=0
      ratio_end=1
    }
  fi

  local len=${#input}
  local from_boundary to_boundary expanded

  from_boundary=$(num_product "$len" "$ratio_start" 0)
  to_boundary=$(num_product "$len" "$ratio_end" 0)

  __string_match_expand_into expanded \
      "$input" "$regex" "$from_boundary" "$to_boundary"

  local match _
  IFS="$sep" read -r _ match _ <<< "$expanded"

  printf '%s\n' "$match"

  return 0
}
