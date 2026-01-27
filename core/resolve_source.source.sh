#!/usr/bin/env bash
# Source-only library: resolve_source <selector...>
# - action: source matched *.source.sh files
# - stdout: (none)
# - stderr: diagnostics only (optional)
# - return: always 0

# Prevent multiple sourcing
[[ -n "${__RESOLVE_SOURCE_SOURCED+x}" ]] && return 0
__RESOLVE_SOURCE_SOURCED=1

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "[ERROR] $(basename "${BASH_SOURCE[0]}") must be sourced, not executed." >&2
  exit 1
fi

# scripts/core/resolve_source.source.sh
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/log.source.sh"

resolve_source() {
  local mod="RESOLVE_SOURCE"
  local root="$1"
  shift

  if [[ ! -d "$root" ]]; then
    logd "$mod" "root directory '$root' does not exist."
    return 0
  fi

  local source_dir="$root/source" 
  if [[ ! -d "$source_dir" ]]; then
    logd "$mod" "source directory '$source_dir' does not exist."
    return 0
  fi

  if [[ "$#" -eq 0 ]]; then
    logd "$mod" "no selectors provided."
    return 0
  fi

  local _nullglob_was_set
  _nullglob_was_set="$(shopt -p nullglob)"

  # Avoid literal '*.source.sh' when no files exist
  shopt -s nullglob

  local sources=("$source_dir"/*.source.sh)
  if [[ ${#sources[@]} -eq 0 ]]; then
    eval "$_nullglob_was_set"
    return 0
  fi

  local file selector
  for file in "${sources[@]}"; do
    local name="${file##*/}"
    for selector in "$@"; do
      [[ "$name" == *"$selector"*".source.sh" ]] || continue
      # shellcheck source=/dev/null
      source "$file"

      logd "$mod" "loaded $name"

      break
    done
  done

  eval "$_nullglob_was_set"
  return 0
}