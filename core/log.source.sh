#!/usr/bin/env bash
# shellcheck shell=bash
# Source-only library: log
# - provides logging functions: _debug, _info, _warn, _error
# - stdout: (none)
# - stderr: log messages
# - return: always 0

# Prevent multiple sourcing
[[ -n "${__LOG_SOURCED+x}" ]] && return 0
__LOG_SOURCED=1

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "[ERROR] $(basename "${BASH_SOURCE[0]}") must be sourced." >&2
  exit 1
fi

logd() {
  local module="$1"
  shift
  [[ -n "$module" ]] || return 0

  local var="${module}_DEBUG"

  if [[ -n "${!var+x}" ]]; then
    [[ "${!var}" == "1" ]] || return 0
  else
    [[ "${DEBUG:-0}" == "1" ]] || return 0
  fi

  echo "[DEBUG] $module: $*" >&2
}

logi() {
  local module="$1"
  shift
  [[ -n "$module" ]] || return 0
  echo "[INFO] $module: $*" >&2
}

logw() {
  local module="$1"
  shift
  [[ -n "$module" ]] || return 0
  echo "[WARN] $module: $*" >&2
}

loge() {
  local module="$1"
  shift
  [[ -n "$module" ]] || return 0
  echo "[ERROR] $module: $*" >&2
}
