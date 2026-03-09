#!/usr/bin/env bash
# Source-only library: lib/file

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__FILE_SOURCED+x}" ]] && return 0
__FILE_SOURCED=1

# --- Public API --------------------------------------------------------------

file_tmp() {
  local dir="${1:?file_tmp: missing dir}"
  local ext="${2:-}"
  local tmp

  dir="${dir%/}"
  tmp="$(mktemp "$dir/.tmp.XXXXXX")" || return 1
  [[ -n "$ext" ]] && tmp="$tmp.$ext"

  printf '%s\n' "$tmp"
}
