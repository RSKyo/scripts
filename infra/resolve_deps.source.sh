#!/usr/bin/env bash
# Source-only library: resolve_deps VAR=script.name [...]
# - action: resolve and bind required action/*.sh scripts
# - scope: action directory, exact name match
# - stdout: (none)
# - stderr: error diagnostics
# - exit: program terminates on any failure

# Prevent multiple sourcing
[[ -n "${__RESOLVE_DEPS_SOURCED+x}" ]] && return 0
__RESOLVE_DEPS_SOURCED=1

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)/bootstrap.source.sh"

resolve_deps() {
  local kv var name file

  if [[ ! -d "$ACTION_DIR" ]]; then
    loge "infra" "action directory not found: $ACTION_DIR"
    exit 1
  fi

  if [[ "$#" -eq 0 ]]; then
    loge "infra" "no dependencies provided to resolve_deps"
    exit 1
  fi

  for kv in "$@"; do
    var="${kv%%=*}"
    name="${kv#*=}"

    if [[ -z "$var" || -z "$name" || "$var" == "$name" ]]; then
      loge "infra" "invalid dependency declaration: $kv"
      exit 1
    fi

    file="$ACTION_DIR/$name.sh"

    if [[ ! -f "$file" ]]; then
      loge "infra" "dependency not found: $file"
      exit 1
    fi

    if [[ ! -x "$file" ]]; then
      loge "infra" "dependency not executable: $file"
      exit 1
    fi

    printf -v "$var" '%s' "$file"
    logd "infra" "resolved $var -> $file"
  done

  return 0
}
