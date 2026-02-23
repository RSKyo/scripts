#!/usr/bin/env bash
# array.source.sh
# array utilities module.

# Prevent multiple sourcing
[[ -n "${__ARRAY_SOURCED+x}" ]] && return 0
__ARRAY_SOURCED=1

# array_distinct_count <arr_ref>
# Print number of unique elements in array.
array_distinct_count() {
  local -n arr_ref="$1"
  local -A seen=()
  local item
  for item in "${arr_ref[@]}"; do
    seen["$item"]=1
  done
  printf '%s\n' "${#seen[@]}"
}