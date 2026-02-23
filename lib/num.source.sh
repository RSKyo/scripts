#!/usr/bin/env bash
# num.source.sh
# num utilities module.

# Prevent multiple sourcing
[[ -n "${__NUM_SOURCED+x}" ]] && return 0
__NUM_SOURCED=1

# Internal calculation scale.
__NUM_CALC_SCALE=6

# -------------------------------------------------
# Internal Helpers (name-ref only)
# -------------------------------------------------

# __num_scaled <out_ref> <decimal>
# Convert decimal string to internal fixed-point integer.
# - Uses __NUM_CALC_SCALE as calculation precision.
# - Truncates extra fractional digits (no rounding).
# - Supports negative values.
# - Result written to <out_ref>.
__num_scaled() {
  local -n out="$1"
  local value="$2"
  
  local calc_scale="$__NUM_CALC_SCALE"
  local sign=1
  local integer fraction
  local scaled

  [[ $value == -* ]] && {
    sign=-1
    value="${value#-}"
  }

  IFS='.' read -r integer fraction <<< "$value"

  integer="${integer:-0}"
  fraction="${fraction:0:$calc_scale}"

  scaled=$(( integer * 10**calc_scale ))

  if [[ -n $fraction ]]; then
    scaled=$(( scaled + fraction * 10**(calc_scale - ${#fraction}) ))
  fi

  # shellcheck disable=SC2034
  out=$(( sign * scaled ))
}

# __num_scaled_into <out_ref> <decimal>
# Safe wrapper for __num_scaled.
# - Isolates name-reference scope.
# - Prevents variable collisions.
# - Result written to <out_ref>.
__num_scaled_into() {
  local -n out="$1"
  local __num_scaled_value="$2"
  local __num_scaled_out

  __num_scaled __num_scaled_out \
    "$__num_scaled_value"
  
  # shellcheck disable=SC2034
  out="$__num_scaled_out"
}

# __num_restored <out_ref> <scaled_int> [scale] [trim]
# Restore internal fixed-point integer to decimal string.
# - Adjusts from internal calculation scale to requested precision.
# - Optionally trims trailing zeros in fractional part.
# - Supports negative values.
# - Result written to <out_ref>.
__num_restored() {
  local -n out="$1"
  local value="$2"
  local scale="${3:-3}"
  local trim="${4:-1}"

  local calc_scale="$__NUM_CALC_SCALE"
  local sign=1
  local pow integer fraction
  local restored

  (( value < 0 )) && {
    sign=-1
    value=$(( -value ))
  }

  if (( scale == 0 )); then
    value=$(( value / 10**calc_scale ))
    out="$(( sign * value ))"
    return 0
  fi

  # adjust internal scale to requested precision
  if (( calc_scale > scale )); then
    value=$(( value / 10**(calc_scale - scale) ))
  elif (( calc_scale < scale )); then
    value=$(( value * 10**(scale - calc_scale) ))
  fi

  pow=$((10**scale))
  integer=$(( value / pow ))
  fraction=$(printf "%0*d" "$scale" "$(( value % pow ))")

  if (( trim )); then
    fraction="${fraction%"${fraction##*[!0]}"}"
  fi

  restored="$(( sign * integer ))"
  [[ -n $fraction ]] && restored+=".$fraction"

  # shellcheck disable=SC2034
  out="$restored"
}

# __num_restored_into <out_ref> <scaled_int> [scale] [trim]
# Safe wrapper for __num_restored.
# - Isolates name-reference scope.
# - Prevents variable collisions.
# - Result written to <out_ref>.
__num_restored_into() {
  local -n out="$1"
  local __num_restored_value="$2"
  local __num_restored_scale="${3:-3}"
  local __num_restored_trim="${4:-1}"
  local __num_restored_out

  __num_restored __num_restored_out \
    "$__num_restored_value" \
    "$__num_restored_scale" \
    "$__num_restored_trim"

  # shellcheck disable=SC2034
  out="$__num_restored_out"
}

# -------------------------------------------------
# Public API (stdout interface)
# -------------------------------------------------

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
  __num_scaled_into scaled "$value"
  __num_restored_into restored "$scaled" "$scale" "$trim"

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
  __num_scaled_into ai "$a"
  __num_scaled_into bi "$b"
  sum=$(( ai + bi ))
  __num_restored_into restored "$sum" "$scale"

  printf '%s\n' "$restored"
}

# num_diff <a> <b> [scale]
# a - b
num_diff() {
  local a="$1"
  local b="$2"
  local scale="${3:-3}"

  local ai bi diff restored
  __num_scaled_into ai "$a"
  __num_scaled_into bi "$b"
  diff=$(( ai - bi ))
  __num_restored_into restored "$diff" "$scale"
  
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

  __num_scaled_into ai "$a"
  __num_scaled_into bi "$b"
  prod=$(( ai * bi / 10**cs ))
  __num_restored_into restored "$prod" "$scale"

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
  __num_scaled_into ai "$a"
  __num_scaled_into bi "$b"

  (( bi == 0 )) && return 1

  quot=$(( ai * 10**cs / bi ))
  __num_restored_into restored "$quot" "$scale"

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

  __num_scaled_into ai "$a"
  __num_scaled_into bi "$b"

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