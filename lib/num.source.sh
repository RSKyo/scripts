#!/usr/bin/env bash
# num.source.sh
# Basic numeric operations and comparisons using awk for precision.

# Prevent multiple sourcing
[[ -n "${__NUM_SOURCED+x}" ]] && return 0
__NUM_SOURCED=1

# -------------------------------------------------
# Numeric functions
# -------------------------------------------------

# num_format <value> [mode] [scale]
# Format a number with specified rounding mode and decimal places.
# - mode: "trunc" (default) or "round"
# - scale: number of decimal places (default: 3)
num_format() {
  local value="$1"
  local mode="${2:-trunc}"
  local scale="${3:-3}"

  __awk -v x="$value" -v m="$mode" -v s="$scale" '
    BEGIN{
      factor = 10^s

      if (m=="round") {
        printf "%.*f\n", s, x
      } else { # trunc (default)
        printf "%.*f\n", s, int(x*factor)/factor
      }
    }
  '
}

# num_add <a> <b> [mode] [scale]
# Add two numbers with optional formatting.
# - mode: "trunc" (default) or "round"
# - scale: number of decimal places (default: 3)
num_add() {
  local a="$1"
  local b="$2"
  local mode="${3:-trunc}"
  local scale="${4:-3}"

  local result
  result="$(__awk -v a="$a" -v b="$b" 'BEGIN{print a+b}')"

  num_format "$result" "$mode" "$scale"
}

# num_sub <a> <b> [mode] [scale]
# Subtract two numbers with optional formatting.
# - mode: "trunc" (default) or "round"
# - scale: number of decimal places (default: 3)
num_sub() {
  local a="$1"
  local b="$2"
  local mode="${3:-trunc}"
  local scale="${4:-3}"

  local result
  result="$(__awk -v a="$a" -v b="$b" 'BEGIN{print a-b}')"

  num_format "$result" "$mode" "$scale"
}

# num_mul <a> <b> [mode] [scale]
# Multiply two numbers with optional formatting.
# - mode: "trunc" (default) or "round"
# - scale: number of decimal places (default: 3)
num_mul() {
  local a="$1"
  local b="$2"
  local mode="${3:-trunc}"
  local scale="${4:-3}"

  local result
  result="$(__awk -v a="$a" -v b="$b" 'BEGIN{print a*b}')"

  num_format "$result" "$mode" "$scale"
}

# num_div <a> <b> [mode] [scale]
# Divide two numbers with optional formatting.
# - mode: "trunc" (default) or "round"
# - scale: number of decimal places (default: 3)
# Returns 1 if division by zero is attempted.
num_div() {
  local a="$1"
  local b="$2"
  local mode="${3:-trunc}"
  local scale="${4:-3}"

  # avoid division by zero
  [[ "$b" == 0 ]] && return 1

  local result
  result="$(__awk -v a="$a" -v b="$b" 'BEGIN{print a/b}')"

  num_format "$result" "$mode" "$scale"
}

# num_gt <a> <b>
# return 0 if a > b
num_gt() {
  local a="$1"
  local b="$2"

  __awk -v x="$a" -v y="$b" \
    'BEGIN{ exit !(x > y) }'
}

# num_ge <a> <b>
# return 0 if a >= b
num_ge() {
  local a="$1"
  local b="$2"

  __awk -v x="$a" -v y="$b" \
    'BEGIN{ exit !(x >= y) }'
}

# num_lt <a> <b>
# return 0 if a < b
num_lt() {
  local a="$1"
  local b="$2"

  __awk -v x="$a" -v y="$b" \
    'BEGIN{ exit !(x < y) }'
}

# num_le <a> <b>
# return 0 if a <= b
num_le() {
  local a="$1"
  local b="$2"

  __awk -v x="$a" -v y="$b" \
    'BEGIN{ exit !(x <= y) }'
}

# num_eq <a> <b>
# return 0 if a == b
num_eq() {
  local a="$1"
  local b="$2"

  __awk -v x="$a" -v y="$b" \
    'BEGIN{ exit !(x == y) }'
}

# num_ne <a> <b>
# return 0 if a != b
num_ne() {
  local a="$1"
  local b="$2"

  __awk -v x="$a" -v y="$b" \
    'BEGIN{ exit !(x != y) }'
}

# num_between <value> <min> <max>
# return 0 if min <= value <= max
num_between() {
  local val="$1"
  local min="$2"
  local max="$3"

  __awk -v v="$val" -v lo="$min" -v hi="$max" \
    'BEGIN{ exit !(v >= lo && v <= hi) }'
}

# num_ratio_gt <numerator> <denominator> <threshold>
# return 0 if (numerator / denominator) > threshold
# threshold: floating-point (e.g. 0.6)
num_ratio_gt() {
  local num="$1"
  local den="$2"
  local threshold="$3"

  # avoid division by zero
  (( den == 0 )) && return 1

  __awk -v n="$num" -v d="$den" -v th="$threshold" \
    'BEGIN{ exit !(n/d > th) }'
}

# num_ratio_lt <numerator> <denominator> <threshold>
# return 0 if (numerator / denominator) < threshold
# threshold: floating-point (e.g. 0.6)
num_ratio_lt() {
  local num="$1"
  local den="$2"
  local threshold="$3"

  # avoid division by zero
  (( den == 0 )) && return 1

  __awk -v n="$num" -v d="$den" -v th="$threshold" \
    'BEGIN{ exit !(n/d < th) }'
}

# num_ratio_ge <numerator> <denominator> <threshold>
# return 0 if (numerator / denominator) >= threshold
# threshold: floating-point (e.g. 0.6)
num_ratio_ge() {
  local num="$1"
  local den="$2"
  local threshold="$3"

  # avoid division by zero
  (( den == 0 )) && return 1

  __awk -v n="$num" -v d="$den" -v th="$threshold" \
    'BEGIN{ exit !(n/d >= th) }'
}

# num_ratio_le <numerator> <denominator> <threshold>
# return 0 if (numerator / denominator) <= threshold
# threshold: floating-point (e.g. 0.6)
num_ratio_le() {
  local num="$1"
  local den="$2"
  local threshold="$3"

  # avoid division by zero
  (( den == 0 )) && return 1

  __awk -v n="$num" -v d="$den" -v th="$threshold" \
    'BEGIN{ exit !(n/d <= th) }'
}

# num_ratio_between <numerator> <denominator> <min> <max>
# return 0 if min <= (numerator / denominator) <= max
# min/max: floating-point
num_ratio_between() {
  local num="$1"
  local den="$2"
  local min="$3"
  local max="$4"

  # avoid division by zero
  (( den == 0 )) && return 1

  __awk -v n="$num" -v d="$den" -v lo="$min" -v hi="$max" \
    'BEGIN{ r = n/d; exit !(r >= lo && r <= hi) }'
}
