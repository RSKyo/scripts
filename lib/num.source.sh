#!/usr/bin/env bash

# Prevent multiple sourcing
[[ -n "${__NUM_SOURCED+x}" ]] && return 0
__NUM_SOURCED=1

# num_between <value> <min> <max>
# return 0 if min <= value <= max
num_between() {
  local val="$1"
  local min="$2"
  local max="$3"

  (( val >= min && val <= max ))
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
