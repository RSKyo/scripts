#!/usr/bin/env bash
# num.source.sh
# Fixed-point numeric utilities for Bash.
# All arithmetic uses integer scaling.

# shellcheck disable=SC2034

# Prevent multiple sourcing
[[ -n "${__NUM_SOURCED+x}" ]] && return 0
__NUM_SOURCED=1

# Internal calculation scale.
__NUM_CALC_SCALE=6

# __num_scaled <out_ref> <value>
# Convert decimal string to scaled integer.
__num_scaled() {
  local -n __out="$1"
  local __v="$2"
  
  local __cs="$__NUM_CALC_SCALE"
  local __sign=1 __int __frac

  [[ $__v == -* ]] && { __sign=-1; __v="${__v#-}"; }

  IFS='.' read -r __int __frac <<< "$__v"
  __int="${__int:-0}"
  __frac="${__frac:0:$__cs}"

  __out=$(( __int * 10**__cs ))

  [[ -n $__frac ]] &&
    __out=$(( __out + __frac * 10**(__cs - ${#__frac}) ))

  __out=$(( __sign * __out ))
}

# __num_restored <out_ref> <scaled_int> [scale] [trim]
# Convert __scaled integer to decimal string.
# scale: output precision (default 3)
# trim : 1=trim trailing zeros, 0=keep fixed digits
__num_restored() {
  local -n __out="$1"
  local __v="$2"
  local __s="${3:-3}"
  local __t="${4:-1}"
  

  local __cs="$__NUM_CALC_SCALE"
  local __sign=1 __int __frac

  (( __v < 0 )) && { __sign=-1; __v=$(( -__v )); }

  if (( __s == 0 )); then
    if (( __cs > 0 )); then
      __v=$(( __v / 10**__cs ))
    fi
    __out="$(( __sign * __v ))"
    return 0
  fi

  # adjust scale
  if (( __cs > __s )); then
    __v=$(( __v / 10**(__cs - __s) ))
  elif (( __cs < __s )); then
    __v=$(( __v * 10**(__s - __cs) ))
  fi

  __int=$(( __v / 10**__s ))
  __frac=$(printf "%0*d" "$__s" "$(( __v % 10**__s ))")

  if (( __t )); then
    __frac="${__frac%"${__frac##*[!0]}"}"
    __out="$(( __sign * __int ))${__frac:+.$__frac}"
  else
    __out="$(( __sign * __int )).$__frac"
  fi
}

# num_is_int <value>
# True if unsigned integer.
num_is_int() {
  local value="$1"
  [[ $value =~ ^[0-9]+$ ]]
}

# num_is_decimal <value>
# True if signed decimal with fractional part.
num_is_decimal() {
  local value="$1"
  [[ $value =~ ^-?[0-9]+\.[0-9]+$ ]]
}

# num_is_number <value>
# True if signed integer or decimal.
num_is_number() {
  local value="$1"
  [[ $value =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
}

# _num_fixed <out_ref> <value> [scale] [trim]
# Format number by truncation.
_num_fixed() {
  local -n __out="$1"
  local __v="$2"
  local __s="${3:-3}"
  local __t="${4:-1}"

  local __scaled __restored
  __num_scaled __scaled "$__v"
  __num_restored __restored "$__scaled" "$__s" "$__t"
  __out="$__restored"
}

# num_fixed <value> [scale] [trim]
# Public wrapper (stdout).
num_fixed() {
  local fixed
  _num_fixed fixed "$@"
  printf '%s\n' "$fixed"
}

# ---------------------------------------
# Arithmetic
# Internal: _num_*
# Public  : num_*
# ---------------------------------------

# _num_sum <out_ref> <a> <b> [scale]
# a + b
_num_sum() {
  local -n __out="$1"
  local __a="$2"
  local __b="$3"
  local __s="${4:-3}"

  local __ai __bi __restored

  __num_scaled __ai "$__a"
  __num_scaled __bi "$__b"
  __num_restored __restored "$(( __ai + __bi ))" "$__s"

  __out="$__restored"
}

# num_sum <a> <b> [scale]
# Public wrapper (stdout).
num_sum() {
  local sum
  _num_sum sum "$@"
  printf '%s\n' "$sum"
}

# _num_diff <out_ref> <a> <b> [scale]
# a - b
_num_diff() {
  local -n __out="$1"
  local __a="$2"
  local __b="$3"
  local __s="${4:-3}"

  local __ai __bi __restored

  __num_scaled __ai "$__a"
  __num_scaled __bi "$__b"
  __num_restored __restored "$(( __ai - __bi ))" "$__s"
  
  __out="$__restored"
}

# num_diff <a> <b> [scale]
# Public wrapper (stdout).
num_diff() {
  local diff
  _num_diff diff "$@"
  printf '%s\n' "$diff"
}

# _num_product <out_ref> <a> <b> [scale]
# a * b
_num_product() {
  local -n __out="$1"
  local __a="$2"
  local __b="$3"
  local __s="${4:-3}"

  local __ai __bi prod __product
  local __cs="$__NUM_CALC_SCALE"

  __num_scaled __ai "$__a"
  __num_scaled __bi "$__b"
  __num_restored __product "$(( __ai * __bi / 10**__cs ))" "$__s"

  __out="$__product"
}

# num_product <a> <b> [scale]
# Public wrapper (stdout).
num_product() {
  local product
  _num_product product "$@"
  printf '%s\n' "$product"
}

# _num_quotient <out_ref> <a> <b> [scale]
# a / b
# Returns 1 if divisor is zero.
_num_quotient() {
  local -n __out="$1"
  local __a="$2"
  local __b="$3"
  local __s="${4:-3}"

  local __ai __bi __restored
  local __cs="$__NUM_CALC_SCALE"

  __num_scaled __ai "$__a"
  __num_scaled __bi "$__b"

  (( __bi == 0 )) && return 1

  __num_restored __restored "$(( __ai * 10**__cs / __bi ))" "$__s"

  __out="$__restored"
}

# num_quotient <a> <b> [scale]
# Public wrapper (stdout).
num_quotient() {
  local quotient
  _num_quotient quotient "$@" || return 1
  printf '%s\n' "$quotient"
}

# num_cmp <a> <op> <b>
# Compare two values.
# op: gt ge lt le eq ne
# Return: 0=true, 1=false, 2=invalid op
num_cmp() {
  local a="$1"
  local op="$2"
  local b="$3"

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

# num_between <value> <lo> <hi>
# True if lo <= value <= hi.
num_between() {
  local v="$1"
  local lo="$2"
  local hi="$3"

  num_cmp "$v" ge "$lo" &&
  num_cmp "$v" le "$hi"
}

# num_ratio_cmp <num> <den> <op> <th>
# Compare (num / den) with threshold.
# Return: 0=true, 1=false, 2=invalid op
num_ratio_cmp() {
  local num="$1"
  local den="$2"
  local op="$3"
  local th="$4"

  local cs="$__NUM_CALC_SCALE"
  local ni di ti rhs

  __num_scaled ni "$num"
  __num_scaled di "$den"
  __num_scaled ti "$th"

  (( di == 0 )) && return 1

  # Cross-multiply:
  # num  op  th * den
  # Reverse inequality if den < 0.
  rhs=$(( (ti * di) / 10**cs ))

  if (( di < 0 )); then
    case "$op" in
      gt) op="lt" ;;
      ge) op="le" ;;
      lt) op="gt" ;;
      le) op="ge" ;;
    esac
  fi

  case "$op" in
    gt) (( ni >  rhs )) ;;
    ge) (( ni >= rhs )) ;;
    lt) (( ni <  rhs )) ;;
    le) (( ni <= rhs )) ;;
    eq) (( ni == rhs )) ;;
    ne) (( ni != rhs )) ;;
    *)  return 2 ;;
  esac
}

# num_ratio_between <num> <den> <lo> <hi>
# True if lo <= (num / den) <= hi.
num_ratio_between() {
  local num="$1"
  local den="$2"
  local lo="$3"
  local hi="$4"

  num_ratio_cmp "$num" "$den" ge "$lo" &&
  num_ratio_cmp "$num" "$den" le "$hi"
}
