#!/usr/bin/env bash
# Source-only library: resolve_source <selector...>
# - action: source matched lib/*.source.sh files
# - scope: lib directory only (non-recursive)
# - stdout: (none)
# - stderr: diagnostics only (debug)
# - return: always 0

# Prevent multiple sourcing
[[ -n "${__uIIGTsSG+x}" ]] && return 0
__uIIGTsSG=1

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)/log.source.sh"

resolve_source() {
  local base_dir root_dir lib_dir
  local selector file name

  base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
  root_dir="$(cd "$base_dir/.." >/dev/null && pwd)"
  lib_dir="$root_dir/lib"

  if [[ ! -d "$lib_dir" ]]; then
    logd "infra" "lib directory not found: $lib_dir"
    return 0
  fi

  if [[ "$#" -eq 0 ]]; then
    logd "infra" "no selectors provided to resolve_source"
    return 0
  fi

  for file in "$lib_dir"/*.source.sh; do
    [[ -f "$file" ]] || continue
    name="${file##*/}"

    for selector in "$@"; do
      [[ "$name" == *"$selector"*".source.sh" ]] || continue

      # shellcheck source=/dev/null
      source "$file"
      logd "infra" "loaded $name"
      break
    done
  done

  return 0
}
