#!/usr/bin/env bash
# shellcheck shell=bash
# Source-only library: log
# Provides simple logging functions.
# - debug output controlled by debug_on / debug_off
# - logs print to stderr

# Prevent multiple sourcing
[[ -n "${__LOG_SOURCED+x}" ]] && return 0
__LOG_SOURCED=1

# Debug flag (default: off)
__LOG_DEBUG=0

# Output function name flag (default: off)
__LOG_FUNC=0

# -------------------------------------------------
# Internal Helpers
# -------------------------------------------------

# Emit a log line to stderr.
# Format: [LEVEL] function(): message
__log_emit() {
  local level="$1"
  shift

  local prefix="[$level]"

  if [[ "$__LOG_FUNC" == "1" ]]; then
    prefix+=" ${FUNCNAME[2]:-MAIN}():"
  else
    prefix+=":"
  fi

  printf '%s %s\n' "$prefix" "$*" >&2
}

# -------------------------------------------------
# Public API
# -------------------------------------------------

debug_on()  { __LOG_DEBUG=1; }
debug_off() { __LOG_DEBUG=0; }
log_func_on()  { __LOG_FUNC=1; }
log_func_off() { __LOG_FUNC=0; }

# Debug log (only prints when debug is on)
logd() {
  [[ "$__LOG_DEBUG" == "1" ]] || return 0
  __log_emit "DEBUG" "$@"
}

# Always print
logi() { __log_emit "INFO"  "$@"; }
logw() { __log_emit "WARN"  "$@"; }
loge() { __log_emit "ERROR" "$@"; }
