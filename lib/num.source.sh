#!/usr/bin/env bash
# Source-only library: lib/num

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__NUM_SOURCED+x}" ]] && return 0
__NUM_SOURCED=1

# --- Constants ---------------------------------------------------------------

# Internal calculation scale.
readonly __NUM_CALC_SCALE=6

# --- Internal Helpers --------------------------------------------------------

__num_scaled() {
  local -n _scaled_ref="$1"
  local _value="$2"
  
  local sign=1
  local integer fraction

  [[ $_value == -* ]] && {
    sign=-1
    _value="${_value#-}"
  }

  IFS='.' read -r integer fraction <<< "$_value"

  integer="${integer:-0}"
  fraction="${fraction:0:$__NUM_CALC_SCALE}"

  _scaled_ref=$(( integer * 10**__NUM_CALC_SCALE ))

  if [[ -n $fraction ]]; then
    _scaled_ref=$(( _scaled_ref + fraction * 10**(__NUM_CALC_SCALE - ${#fraction}) ))
  fi

  _scaled_ref=$(( sign * _scaled_ref ))
}

__num_restored() {
  local -n _restored_ref="$1"
  local _value="$2"
  local scale="${3:-3}"
  local trim="${4:-1}"

  local sign=1
  local pow integer fraction

  (( _value < 0 )) && {
    sign=-1
    _value=$(( -_value ))
  }

  if (( scale == 0 )); then
    _value=$(( _value / 10**__NUM_CALC_SCALE ))
    _restored_ref="$(( sign * _value ))"
    return 0
  fi

  # adjust internal scale to requested precision
  if (( __NUM_CALC_SCALE > scale )); then
    _value=$(( _value / 10**(__NUM_CALC_SCALE - scale) ))
  elif (( __NUM_CALC_SCALE < scale )); then
    _value=$(( _value * 10**(scale - __NUM_CALC_SCALE) ))
  fi

  pow=$((10**scale))
  integer=$(( _value / pow ))
  fraction=$(printf "%0*d" "$scale" "$(( _value % pow ))")

  if (( trim )); then
    fraction="${fraction%"${fraction##*[!0]}"}"
  fi

  _restored_ref="$(( sign * integer ))"
  [[ -n $fraction ]] && _restored_ref+=".$fraction"

  return 0
}

# --- Public API --------------------------------------------------------------

# num_like_int <value>
# Return true if the string looks like a signed integer.
num_like_zero() {
  [[ $1 =~ ^(0(\.0*)?|\.[0]+)$ ]]
}

# num_like_zero <value>
# True if string represents zero in loose form (e.g. 0, 0.0, .0).
num_like_int() {
  [[ $1 =~ ^-?[0-9]+$ ]]
}

# num_like_nonneg_int <value>
# Return true if the string looks like a non-negative integer (>= 0).
# Accepted forms: 0, 01, 0003
num_like_nonneg_int() {
  [[ $1 =~ ^[0-9]+$ ]]
}

# num_like_pos_int <value>
# Return true if the string looks like a positive integer (> 0).
# Accepted forms: 1, 10, 001
num_like_pos_int() {
  [[ $1 =~ ^[1-9][0-9]*$ ]]
}

# num_is_int <value>
# Return true if signed integer.
num_is_int() {
  [[ $1 =~ ^-?(0|[1-9][0-9]*)$ ]]
}

# num_is_nonneg_int <value>
# Return true if non-negative integer (>= 0).
num_is_nonneg_int() {
  [[ $1 =~ ^(0|[1-9][0-9]*)$ ]]
}

# num_is_pos_int <value>
# Return true if positive integer (> 0).
num_is_pos_int() {
  [[ $1 =~ ^[1-9][0-9]*$ ]]
}

# num_is_decimal <value>
# Return true if signed decimal with fractional part.
num_is_decimal() {
  [[ $1 =~ ^-?(0|[1-9][0-9]*)\.[0-9]+$ ]]
}

# num_is_nonneg_decimal <value>
# Return true if non-negative decimal with fractional part (>= 0).
num_is_nonneg_decimal() {
  [[ $1 =~ ^(0|[1-9][0-9]*)\.[0-9]+$ ]]
}

# num_is_pos_decimal <value>
# Return true if positive decimal with fractional part (> 0).
num_is_pos_decimal() {
  [[ $1 =~ ^(0|[1-9][0-9]*)\.[0-9]+$ && ! $1 =~ ^0\.0+$ ]]
}

# num_is_number <value>
# Return true if signed integer or decimal.
num_is_number() {
  [[ $1 =~ ^-?(0|[1-9][0-9]*)(\.[0-9]+)?$ ]]
}

# num_is_nonneg_number <value>
# Return true if non-negative integer or decimal.
num_is_nonneg_number() {
  [[ $1 =~ ^(0|[1-9][0-9]*)(\.[0-9]+)?$ ]]
}

# num_is_pos_number <value>
# Return true if positive integer or decimal.
num_is_pos_number() {
  [[ $1 =~ ^(0|[1-9][0-9]*)(\.[0-9]+)?$ && ! $1 =~ ^0(\.0+)?$ ]]
}

# num_fixed <value> [scale] [trim]
# Format number with fixed precision by truncation.
# - scale: decimal places (default 3)
# - trim: remove trailing zeros if non-zero (default 1)
# - Output printed to stdout.
num_fixed() {
  local value="$1"
  local scale="${2:-3}"
  local trim="${3:-1}"

  local scaled restored
  __num_scaled scaled "$value"
  __num_restored restored "$scaled" "$scale" "$trim"

  printf '%s\n' "$restored"
}

# ---------------------------------------
# Arithmetic
# Internal: _num_*
# Public  : num_*
# ---------------------------------------

# num_sum <a> <b> [scale]
# a + b
num_sum() {
  local a="$1"
  local b="$2"
  local scale="${3:-3}"

  local ai bi sum restored
  __num_scaled ai "$a"
  __num_scaled bi "$b"
  sum=$(( ai + bi ))
  __num_restored restored "$sum" "$scale"

  printf '%s\n' "$restored"
}

# num_diff <a> <b> [scale]
# a - b
num_diff() {
  local a="$1"
  local b="$2"
  local scale="${3:-3}"

  local ai bi diff restored
  __num_scaled ai "$a"
  __num_scaled bi "$b"
  diff=$(( ai - bi ))
  __num_restored restored "$diff" "$scale"
  
  printf '%s\n' "$restored"
}

# num_product <a> <b> [scale]
# a * b
num_product() {
  local a="$1"
  local b="$2"
  local scale="${3:-3}"

  local ai bi prod restored
  local cs="$__NUM_CALC_SCALE"

  __num_scaled ai "$a"
  __num_scaled bi "$b"
  prod=$(( ai * bi / 10**cs ))
  __num_restored restored "$prod" "$scale"

  printf '%s\n' "$restored"
}

# num_quotient <a> <b> [scale]
# a / b
# Returns 1 if divisor is zero.
num_quotient() {
  local a="$1"
  local b="$2"
  local scale="${3:-3}"

  local ai bi quot restored
  local cs="$__NUM_CALC_SCALE"
  __num_scaled ai "$a"
  __num_scaled bi "$b"

  (( bi == 0 )) && return 1

  quot=$(( ai * 10**cs / bi ))
  __num_restored restored "$quot" "$scale"

  printf '%s\n' "$restored"
}

# num_cmp <a> <op> <b>
# Compare two values.
# op: gt ge lt le eq ne
# Return: 0=true, 1=false, 2=invalid op
num_cmp() {
  local a="$1"
  local op="$2"
  local b="$3"

  num_is_number "$a" || return 1
  num_is_number "$b" || return 1

  local ai bi

  __num_scaled ai "$a"
  __num_scaled bi "$b"

  case "$op" in
    gt) (( ai >  bi )) ;;
    ge) (( ai >= bi )) ;;
    lt) (( ai <  bi )) ;;
    le) (( ai <= bi )) ;;
    eq) (( ai == bi )) ;;
    ne) (( ai != bi )) ;;
    *)  return 2 ;;
  esac
}

# num_between <value> <lo> <hi> [--left-open] [--right-open]
# True if value is in range (default [lo, hi]).
# --left-open  => (lo, hi]
# --right-open => [lo, hi)
num_between() {
  local value="$1"
  local lo="$2"
  local hi="$3"
  shift 3

  num_is_number "$value" || return 1
  num_is_number "$lo" || return 1
  num_is_number "$hi" || return 1

  local left_open=0 right_open=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --left-open) left_open=1 ;;
      --right-open) right_open=1 ;;
      --) shift; break ;;
      *) break ;;
    esac
    shift
  done

  local lop="ge" rop="le"
  (( left_open )) && lop="gt"
  (( right_open )) && rop="lt"

  num_cmp "$value" "$lop" "$lo" &&
  num_cmp "$value" "$rop" "$hi"
}

# num_random_int32
# Build a wider pseudo-random integer from two 15-bit $RANDOM values.
# Structure: (high_bits << 16) XOR low_bits.
# Increases entropy compared to a single $RANDOM.
# Not suitable for security-sensitive use.
num_random_int32() {
  printf '%u\n' $(( (RANDOM << 16) ^ RANDOM ))
}