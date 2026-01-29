#!/usr/bin/env bash
# Source-only guard: ensure file is sourced, not executed

# Prevent multiple sourcing
[[ -n "${__eTe6fzSY+x}" ]] && return 0
__eTe6fzSY=1

guard_source() {
  if [[ "${BASH_SOURCE[1]}" == "$0" ]]; then
    echo "[ERROR] $(basename "${BASH_SOURCE[1]}") must be sourced." >&2
    exit 1
  fi
}
