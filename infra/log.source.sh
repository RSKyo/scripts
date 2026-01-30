#!/usr/bin/env bash
# shellcheck shell=bash
# Source-only library: log
# - provides logging functions: _debug, _info, _warn, _error
# - stdout: (none)
# - stderr: log messages
# - return: always 0

# Prevent multiple sourcing
[[ -n "${__wfI6ogTw+x}" ]] && return 0
__wfI6ogTw=1

_log_emit() {
  local level="$1"
  local scope="$2"
  local func="$3"
  shift 3

  echo "[$level] $scope: ${func}(): $*" >&2
}

logd() {
  local scope="$1"
  shift
  [[ -n "$scope" ]] || return 0

  # normalize names
  local scope_l="${scope,,}"
  local scope_u="${scope^^}"
  
  local var_l="${scope_l}_debug"
  local var_u="${scope_u}_DEBUG"
  
  if [[ -n "${!var_l+x}" ]]; then
    [[ "${!var_l}" == "1" ]] || return 0
  elif [[ -n "${!var_u+x}" ]]; then
    [[ "${!var_u}" == "1" ]] || return 0
  else
    [[ "${DEBUG:-0}" == "1" ]] || return 0
  fi

  local level="DEBUG"
  local func="${FUNCNAME[1]:-MAIN}"
  _log_emit "$level" "$scope" "$func" "$@"
}

logi() {
  local scope="$1"
  shift
  [[ -n "$scope" ]] || return 0
  local level="INFO"
  local func="${FUNCNAME[1]:-MAIN}"
  _log_emit "$level" "$scope" "$func" "$@" 
}

logw() {
  local scope="$1"
  shift
  [[ -n "$scope" ]] || return 0
  local level="WARN"
  local func="${FUNCNAME[1]:-MAIN}"
  _log_emit "$level" "$scope" "$func" "$@" 
}

loge() {
  local scope="$1"
  shift
  [[ -n "$scope" ]] || return 0
  local level="ERROR"
  local func="${FUNCNAME[1]:-MAIN}"
  _log_emit "$level" "$scope" "$func" "$@"
}
