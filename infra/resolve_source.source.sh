#!/usr/bin/env bash
# Source-only library: resolve_source <selector...>
# - action: source matched lib/*.source.sh files
# - scope: lib directory only (non-recursive)
# - stdout: (none)
# - stderr: diagnostics only (debug)
# - return: always 0

# Prevent multiple sourcing
[[ -n "${__bApqO7xE+x}" ]] && return 0
__bApqO7xE=1

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)/bootstrap.source.sh"

resolve_source() {
  local selector file name

  if [[ ! -d "$LIB_DIR" ]]; then
    logd "infra" "lib directory not found: $LIB_DIR"
    return 0
  fi

  if [[ "$#" -eq 0 ]]; then
    logd "infra" "no selectors provided to resolve_source"
    return 0
  fi

  for file in "$LIB_DIR"/*.source.sh; do
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
