#!/usr/bin/env bash
# Source-only library: random_id
# Usage:
#   random_id            # default 8
#   random_id 12         # custom length

# Prevent multiple sourcing
[[ -n "${__bnuXprz6+x}" ]] && return 0
__bnuXprz6=1

random_id() {
  local len="${1:-8}"

  # basic validation: positive integer
  [[ "$len" =~ ^[0-9]+$ ]] || {
    echo "[random_id] length must be a positive integer" >&2
    return 1
  }

  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len"
  printf '\n'
}
